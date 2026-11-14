// VenStore rope texture generator (the blind cord beside the shelves).
//
// Run from PowerShell in the addon folder:
//   Add-Type -Path tools\RopeGen.cs -ReferencedAssemblies System.Drawing
//   [RopeGen]::Rope("$PWD\textures\rope.tga", "$PWD\rope_preview.png")
//
// Output: 16x64 32-bit TGA with alpha that tiles vertically. One lay (a full turn) of a
// three-strand hemp rope seen from the side: the strands run diagonally across the rope, each
// rounded and lit from the upper left, with dark grooves between them, fine fibres along each
// strand and a slightly bumpy outline where the strands bulge. The preview PNG shows four tiles
// 6x on parchment.
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;

public static class RopeGen
{
    const int W = 16, H = 64, SS = 4;   // supersampling per axis
    const int STRANDS = 3;

    static double Clamp(double v, double a, double b) { return v < a ? a : (v > b ? b : v); }
    static double Hash(int x, int y) { unchecked { int h = x * 374761393 + y * 668265263; h = (h ^ (h >> 13)) * 1274126177; return ((h ^ (h >> 16)) & 0xffff) / 65535.0; } }
    static double Smooth(double a, double b, double v) { double t = Clamp((v - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); }
    static double Frac(double v) { return v - Math.Floor(v); }

    // Sample one point: returns coverage alpha and colour.
    static void Sample(double px, double py, out double a, out double r, out double g, out double b)
    {
        double u = (px - W / 2.0) / (W / 2.0);          // -1 (left edge) .. 1 (right edge)
        a = 0; r = g = b = 0;
        if (Math.Abs(u) >= 1) return;
        double theta = Math.Asin(u);                     // angle round the rope's axis

        // Position along the helix, in strands: the boundaries between strands are where this is
        // a whole number. A right-hand (Z) lay: strands climb from lower left to upper right.
        double phase = (py / H - theta / (2 * Math.PI)) * STRANDS;
        double s = Frac(phase);                          // 0..1 across one strand
        int strand = (int)Math.Floor(phase);

        // Each strand is a rounded bundle: it bulges at its middle and sinks into the grooves.
        double bulge = Math.Sin(Math.PI * s);            // 0 in a groove, 1 on the crest
        double groove = Smooth(0.16, 0.0, Math.Min(s, 1 - s));

        // Outline: the rope is a little narrower in the grooves, so its edge looks bumpy.
        double halfW = 0.80 + 0.20 * Math.Pow(bulge, 0.6);
        double edge = Smooth(halfW, halfW - 0.18, Math.Abs(u));
        if (edge <= 0) return;

        // Lighting: the rope's roundness (across) and the strand's roundness (along the rope),
        // lit from the upper left and slightly in front.
        double nx = u;
        double nz = Math.Sqrt(Math.Max(0, 1 - u * u));
        double tilt = Math.Cos(Math.PI * s);             // strand surface faces up at s < 0.5
        double ny = 0.55 * tilt;
        double len = Math.Sqrt(nx * nx + ny * ny + nz * nz);
        double lx = -0.45, ly = 0.55, lz = 0.70;
        double diffuse = Math.Max(0, (nx * lx + ny * ly + nz * lz) / len);
        double light = 0.30 + 0.80 * diffuse + 0.18 * Math.Pow(diffuse, 12);

        // Fibres: fine streaks that run along each strand, and a few stray light hairs.
        double along = py / H * STRANDS * 6 + theta * 1.3;
        // (Both noise lookups wrap at the tile's height so the texture repeats without a seam.)
        int strandMod = ((strand % STRANDS) + STRANDS) % STRANDS;
        int alongMod = (((int)Math.Floor(along)) % (STRANDS * 6) + STRANDS * 6) % (STRANDS * 6);
        double fibre = 0.86 + 0.14 * Hash((int)Math.Floor(s * 9) + strandMod * 31, alongMod);
        double hair = Hash((int)Math.Floor(px * 2), (int)Math.Floor(py * 1.5) % (H * 3 / 2)) > 0.985 ? 0.25 : 0;

        double shade = light * fibre * (1 - 0.62 * groove) + hair;
        // Hemp: warm straw on the crests, browner in the grooves; strands differ slightly.
        double tint = 0.94 + 0.06 * Hash(((strand % STRANDS) + STRANDS) % STRANDS, 7);
        r = 0.80 * shade * tint; g = 0.67 * shade * tint; b = 0.44 * shade * (tint - 0.04);
        a = edge;
    }

    public static void Rope(string tgaPath, string pngPath)
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
            const int Z = 6, TILES = 4;
            using (var bmp = new Bitmap(W * Z, H * Z * TILES, PixelFormat.Format32bppArgb))
            {
                for (int y = 0; y < H * Z * TILES; y++)
                    for (int x = 0; x < W * Z; x++)
                    {
                        int ix = x / Z, iy = (y / Z) % H;
                        double a = img[ix, iy, 3];
                        double br = 0.82, bg = 0.70, bb = 0.50; // parchment backdrop
                        bmp.SetPixel(x, y, Color.FromArgb(255,
                            (int)(Clamp(img[ix, iy, 0] * a + br * (1 - a), 0, 1) * 255),
                            (int)(Clamp(img[ix, iy, 1] * a + bg * (1 - a), 0, 1) * 255),
                            (int)(Clamp(img[ix, iy, 2] * a + bb * (1 - a), 0, 1) * 255)));
                    }
                bmp.Save(pngPath, ImageFormat.Png);
            }
        }
    }
}
