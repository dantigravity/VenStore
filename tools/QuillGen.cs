// VenStore quill texture generator.
//
// Run from PowerShell in the addon folder:
//   Add-Type -Path tools\QuillGen.cs -ReferencedAssemblies System.Drawing
//   [QuillGen]::Quill("$PWD\textures\quill.tga", "$PWD\quill_preview.png")
//
// Output: 32x128 32-bit TGA with alpha. A white goose-feather quill standing upright: dark inked
// nib at the bottom, bare shaft, then the vane (wider on the left), with barbs, a few splits and
// downy fluff at its base. The preview PNG shows it 4x on parchment.
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;

public static class QuillGen
{
    const int W = 32, H = 128, SS = 4; // supersampling per axis

    static double Clamp(double v, double a, double b) { return v < a ? a : (v > b ? b : v); }
    static double Hash(int x, int y) { unchecked { int h = x * 374761393 + y * 668265263; h = (h ^ (h >> 13)) * 1274126177; return ((h ^ (h >> 16)) & 0xffff) / 65535.0; } }
    static double Smooth(double a, double b, double v) { double t = Clamp((v - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); }

    // Rachis (centre line) x position at height v (0 = nib tip, 1 = top): a gentle curve.
    static double Spine(double v) { return 15.5 + 2.2 * Math.Sin(v * 1.6) - 1.2 * v; }

    // Sample one point: returns coverage alpha and colour.
    static void Sample(double px, double py, out double a, out double r, out double g, out double b)
    {
        double v = 1 - py / H;                 // 0 at the bottom (nib), 1 at the top
        double d = px - Spine(v);              // signed distance from the shaft (+ = right)
        a = 0; r = g = b = 0;

        // Nib: tapered, dark brown horn with an inked tip.
        if (v < 0.14)
        {
            double half = 0.25 + (v / 0.14) * 1.15;
            if (Math.Abs(d) <= half)
            {
                a = 1;
                double ink = Smooth(0.07, 0.0, v);
                double tone = 0.55 + 0.35 * (1 - Math.Abs(d) / half); // rounded
                r = (0.42 * tone) * (1 - ink) + 0.05 * ink;
                g = (0.30 * tone) * (1 - ink) + 0.04 * ink;
                b = (0.18 * tone) * (1 - ink) + 0.08 * ink;
            }
            return;
        }

        // Shaft (always drawn, the vane sits on top of it).
        double shaftHalf = 1.25 - 0.6 * Clamp((v - 0.14) / 0.86, 0, 1);
        bool onShaft = Math.Abs(d) <= shaftHalf && v < 0.97;

        // Vane: starts at v = 0.30, widest around 0.6, rounded tip at the top.
        double vane = 0;
        if (v > 0.30 && v < 0.985)
        {
            double t = (v - 0.30) / 0.685;
            double prof = Math.Pow(Math.Sin(Math.PI * Math.Pow(t, 0.85)), 0.55);
            double halfW = d < 0 ? 10.5 * prof : 6.5 * prof;
            double dist = Math.Abs(d);
            if (dist <= halfW)
            {
                // Barbs run up and outward; a few splits break the vane.
                double along = v * H + dist * 0.85;
                double barb = 0.5 + 0.5 * Math.Sin(along * 1.3);
                int band = (int)Math.Floor(along / 9.0);
                bool split = Hash(band, d < 0 ? 1 : 2) > 0.80 && Math.Abs(along / 9.0 - band - 0.5) < 0.09 && dist > halfW * 0.3;
                double edge = Smooth(halfW, halfW - 1.4, dist);       // soft ragged outer edge
                double rag = 0.85 + 0.15 * Hash((int)(along * 3), (int)(dist * 2));
                vane = split ? 0 : edge;

                // Downy fluff at the base of the vane: fainter, warmer.
                double down = Smooth(0.42, 0.30, v);
                vane *= 1 - 0.45 * down;

                double shade = (0.94 + 0.08 * barb - 0.14 * (dist / Math.Max(halfW, 0.01))) * rag;
                if (d > 0) shade *= 0.88;                             // far side a little in shadow
                r = 0.97 * shade; g = 0.95 * shade; b = 0.90 * shade;
                r = r * (1 - down) + 0.90 * down; g = g * (1 - down) + 0.84 * down; b = b * (1 - down) + 0.74 * down;
                a = vane;
            }
        }
        if (onShaft)
        {
            double sr = 0.93, sg = 0.88, sb = 0.76, k = 0.85 + 0.15 * (1 - Math.Abs(d) / shaftHalf);
            r = r * a * 0.3 + sr * k * (1 - a * 0.3); g = g * a * 0.3 + sg * k * (1 - a * 0.3); b = b * a * 0.3 + sb * k * (1 - a * 0.3);
            a = 1;
        }
    }

    public static void Quill(string tgaPath, string pngPath)
    {
        var img = new double[W, H, 4];
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                double ta = 0, tr = 0, tg = 0, tb = 0;
                for (int sy = 0; sy < SS; sy++)
                    for (int sx = 0; sx < SS; sx++)
                    {
                        double a, r, g, b;
                        Sample(x + (sx + 0.5) / SS, y + (sy + 0.5) / SS, out a, out r, out g, out b);
                        ta += a; tr += r * a; tg += g * a; tb += b * a;
                    }
                double n = SS * SS;
                img[x, y, 3] = ta / n;
                if (ta > 0) { img[x, y, 0] = tr / ta; img[x, y, 1] = tg / ta; img[x, y, 2] = tb / ta; }
            }

        using (var fs = new FileStream(tgaPath, FileMode.Create))
        using (var bw = new BinaryWriter(fs))
        {
            bw.Write((byte)0); bw.Write((byte)0); bw.Write((byte)2);
            bw.Write(new byte[5]);
            bw.Write((short)0); bw.Write((short)0);
            bw.Write((short)W); bw.Write((short)H);
            bw.Write((byte)32); bw.Write((byte)0x28); // 32 bpp, 8 alpha bits, top-left origin
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                {
                    bw.Write((byte)(Clamp(img[x, y, 2], 0, 1) * 255 + 0.5));
                    bw.Write((byte)(Clamp(img[x, y, 1], 0, 1) * 255 + 0.5));
                    bw.Write((byte)(Clamp(img[x, y, 0], 0, 1) * 255 + 0.5));
                    bw.Write((byte)(Clamp(img[x, y, 3], 0, 1) * 255 + 0.5));
                }
        }

        if (pngPath != null)
        {
            const int Z = 4;
            using (var bmp = new Bitmap(W * Z, H * Z, PixelFormat.Format32bppArgb))
            {
                for (int y = 0; y < H * Z; y++)
                    for (int x = 0; x < W * Z; x++)
                    {
                        double a = img[x / Z, y / Z, 3];
                        double br = 0.82, bg = 0.70, bb = 0.50; // parchment backdrop
                        bmp.SetPixel(x, y, Color.FromArgb(255,
                            (int)(Clamp(img[x / Z, y / Z, 0] * a + br * (1 - a), 0, 1) * 255),
                            (int)(Clamp(img[x / Z, y / Z, 1] * a + bg * (1 - a), 0, 1) * 255),
                            (int)(Clamp(img[x / Z, y / Z, 2] * a + bb * (1 - a), 0, 1) * 255)));
                    }
                bmp.Save(pngPath, ImageFormat.Png);
            }
        }
    }
}
