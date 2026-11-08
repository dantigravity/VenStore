using System;
using System.IO;
using System.Drawing;
using System.Drawing.Imaging;

// Procedural plank texture for VenStore (no stock art).
// Output: 1024x128 32-bit uncompressed TGA, horizontally tileable, warm oak tone.
// The addon tints it per surface with SetVertexColor and picks a different slice per board.
//
// Regenerate from PowerShell (in the addon folder):
//   Add-Type -Path tools\WoodGen.cs -ReferencedAssemblies System.Drawing
//   [WoodGen]::Plank("textures\plank.tga", "plank_preview.png", 7)
public static class WoodGen
{
    const int W = 1024, H = 128;

    // ---------------------------------------------------------------- periodic value noise
    static int Seed = 7;
    static double Hash(int x, int y, int s)
    {
        unchecked
        {
            int h = x * 374761393 + y * 668265263 + s * 1442695041 + Seed * 2147483647;
            h = (h ^ (h >> 13)) * 1274126177;
            h ^= h >> 16;
            return (h & 0x7fffffff) / (double)0x7fffffff;
        }
    }
    static double Smooth(double t) { return t * t * (3 - 2 * t); }
    static int Wrap(int v, int p) { int m = v % p; return m < 0 ? m + p : m; }

    // Noise that repeats every `px` cells along x (so the texture tiles horizontally).
    static double Value(double x, double y, int px, int s)
    {
        int xi = (int)Math.Floor(x), yi = (int)Math.Floor(y);
        double xf = x - xi, yf = y - yi;
        int x0 = Wrap(xi, px), x1 = Wrap(xi + 1, px);
        double a = Hash(x0, yi, s), b = Hash(x1, yi, s), c = Hash(x0, yi + 1, s), d = Hash(x1, yi + 1, s);
        double u = Smooth(xf), v = Smooth(yf);
        return (a * (1 - u) + b * u) * (1 - v) + (c * (1 - u) + d * u) * v;
    }
    // fx = cells across the full texture width (integer => seamless), fy = cells per pixel in y.
    static double Fbm(int x, int y, int fx, double fy, int oct, int s)
    {
        double sum = 0, amp = 0.5, norm = 0;
        int f = 1;
        for (int i = 0; i < oct; i++)
        {
            int cells = fx * f;
            sum += amp * Value(x * (double)cells / W, y * fy * f, cells, s + i * 17);
            norm += amp; amp *= 0.5; f *= 2;
        }
        return sum / norm;
    }
    static double Clamp(double v, double a, double b) { return v < a ? a : (v > b ? b : v); }
    static double Lerp(double a, double b, double t) { return a + (b - a) * t; }
    static double SmoothStep(double a, double b, double v) { double t = Clamp((v - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); }

    // ---------------------------------------------------------------- plank
    public static void Plank(string tgaPath, string pngPath, int seed)
    {
        Seed = seed;
        var rnd = new Random(seed);

        // knots: position, radii, strength
        int nk = 3;
        var kx = new double[nk]; var ky = new double[nk]; var kr = new double[nk];
        for (int i = 0; i < nk; i++)
        {
            kx[i] = (i + 0.2 + rnd.NextDouble() * 0.6) * W / nk;
            ky[i] = 25 + rnd.NextDouble() * (H - 50);
            kr[i] = 7 + rnd.NextDouble() * 6;
        }

        var img = new double[W, H, 4];
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                // Growth-ring coordinate: mostly follows y, bent by long low-frequency warps
                // (flat-sawn "cathedral" figure) and swirled around knots.
                double warp = (Fbm(x, y, 3, 0.012, 3, 11) - 0.5) * 7.0
                            + (Fbm(x, y, 9, 0.030, 2, 12) - 0.5) * 1.6;
                double ys = y + (Fbm(x, y, 2, 0.02, 2, 13) - 0.5) * 30.0;
                double d = ys / 8.5 + Math.Sin(ys / 17.0) * 0.9 + warp;
                double knotDark = 0;
                for (int k = 0; k < nk; k++)
                {
                    double dx = x - kx[k];
                    if (dx > W / 2) dx -= W; else if (dx < -W / 2) dx += W;   // wrap
                    double dy = (y - ky[k]) * 1.7;
                    double r = Math.Sqrt(dx * dx * 0.30 + dy * dy);
                    double infl = Math.Exp(-(r * r) / (kr[k] * kr[k] * 9));
                    d += infl * (4.5 - r / kr[k] * 1.1);                        // rings wrap around the knot
                    knotDark = Math.Max(knotDark, 1 - SmoothStep(kr[k] * 0.45, kr[k] * 1.05, r));
                }

                double ring = d - Math.Floor(d);
                // Latewood: a narrow, darker band at the end of each ring with a soft leading edge.
                double late = SmoothStep(0.62, 0.86, ring) * (1 - SmoothStep(0.93, 1.0, ring));
                // Fibres: fine streaks stretched along the board.
                double fibre = Fbm(x, y, 64, 0.55, 3, 21) - 0.5;
                // Pores: short dark dashes.
                double pore = SmoothStep(0.78, 0.92, Value(x * 220.0 / W, y * 0.9, 220, 31));
                // Broad tone variation (sapwood/heartwood, uneven stain).
                double tone = Fbm(x, y, 4, 0.010, 3, 41) - 0.5;

                double streak = Fbm(x, y, 6, 0.09, 2, 51) - 0.5;   // long colour bands along the board
                double light = 0.70 - late * (0.22 + 0.16 * Fbm(x, y, 5, 0.02, 2, 61)) + fibre * 0.18 - pore * 0.09 + tone * 0.26 + streak * 0.14;
                light -= knotDark * 0.42;

                // Warm oak colour; darker areas lean more red-brown like hand-painted Warcraft timber.
                double rr = Lerp(0.24, 0.86, light);
                double gg = Lerp(0.13, 0.60, light * light * 0.55 + light * 0.45);
                double bb = Lerp(0.06, 0.36, light * light * 0.8 + light * 0.2);
                // knot core reddish
                rr += knotDark * 0.05;

                img[x, y, 0] = Clamp(rr, 0, 1);
                img[x, y, 1] = Clamp(gg, 0, 1);
                img[x, y, 2] = Clamp(bb, 0, 1);
                img[x, y, 3] = 1;
            }

        Save(img, tgaPath, pngPath);
    }

    // ---------------------------------------------------------------- output
    static void Save(double[,,] img, string tgaPath, string pngPath)
    {
        int w = img.GetLength(0), h = img.GetLength(1);
        double sr = 0, sg = 0, sb = 0;
        using (var fs = new FileStream(tgaPath, FileMode.Create))
        using (var bw = new BinaryWriter(fs))
        {
            bw.Write((byte)0); bw.Write((byte)0); bw.Write((byte)2);
            bw.Write(new byte[5]);
            bw.Write((short)0); bw.Write((short)0);
            bw.Write((short)w); bw.Write((short)h);
            bw.Write((byte)32); bw.Write((byte)0x28);                       // 32 bpp, 8 alpha bits, top-left origin
            for (int y = 0; y < h; y++)
                for (int x = 0; x < w; x++)
                {
                    bw.Write((byte)(Clamp(img[x, y, 2], 0, 1) * 255 + 0.5));
                    bw.Write((byte)(Clamp(img[x, y, 1], 0, 1) * 255 + 0.5));
                    bw.Write((byte)(Clamp(img[x, y, 0], 0, 1) * 255 + 0.5));
                    bw.Write((byte)(Clamp(img[x, y, 3], 0, 1) * 255 + 0.5));
                    sr += img[x, y, 0]; sg += img[x, y, 1]; sb += img[x, y, 2];
                }
        }
        if (pngPath != null)
        {
            using (var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb))
            {
                for (int y = 0; y < h; y++)
                    for (int x = 0; x < w; x++)
                        bmp.SetPixel(x, y, Color.FromArgb(255,
                            (int)(Clamp(img[x, y, 0], 0, 1) * 255),
                            (int)(Clamp(img[x, y, 1], 0, 1) * 255),
                            (int)(Clamp(img[x, y, 2], 0, 1) * 255)));
                bmp.Save(pngPath, ImageFormat.Png);
            }
        }
        double n = (double)w * h;
        Console.WriteLine(string.Format("average colour: {0:0.000} {1:0.000} {2:0.000}", sr / n, sg / n, sb / n));
    }
}
