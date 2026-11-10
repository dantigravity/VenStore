// BLP texture inspector for picking zone-theme materials (Theme.lua). Not part of the addon.
//
// 1. Find file IDs on https://wago.tools/files (e.g. search "dungeons/textures/silvermooncity").
// 2. Download raw BLPs into a scratch folder: https://wago.tools/api/casc/<fileID>
// 3. From PowerShell:
//      Add-Type -Path tools\BlpSheet.cs -ReferencedAssemblies System.Drawing
//      [BlpSheet]::Sheet("list.txt", "sheet.png", 150, 6)   # list lines: "path\to\id.blp|label"
//      [BlpGrid]::Grid("list.txt", "grid.png", 256, 4)      # same, with a 1/16 grid for band crops
//      [BlpAvg]::Run("blpDir", "avg.txt")                   # lines: "key fileID [a0 a1 u|v]"
//    BlpAvg prints each crop's average colour, used as the role colour in Theme.lua.
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Imaging;
using System.Collections.Generic;

// Decodes BLP2 textures (DXT1/3/5, palettized, ARGB) and lays them out on a labelled contact sheet.
public static class BlpSheet
{
    static Color C565(int c)
    {
        int r = (c >> 11) & 31, g = (c >> 5) & 63, b = c & 31;
        return Color.FromArgb(255, r * 255 / 31, g * 255 / 63, b * 255 / 31);
    }

    static Color Lerp(Color a, Color b, int num, int den)
    {
        return Color.FromArgb(255, (a.R * (den - num) + b.R * num) / den, (a.G * (den - num) + b.G * num) / den,
            (a.B * (den - num) + b.B * num) / den);
    }

    public static Bitmap Decode(string path, int maxSize)
    {
        byte[] d = File.ReadAllBytes(path);
        if (d.Length < 1172 || d[0] != 'B' || d[1] != 'L' || d[2] != 'P' || d[3] != '2') return null;
        int comp = d[8], alphaDepth = d[9], alphaType = d[10];
        int w = BitConverter.ToInt32(d, 12), h = BitConverter.ToInt32(d, 16);
        int mip = 0;
        while ((w >> mip) > maxSize && (h >> mip) > 4 && mip < 15 && BitConverter.ToInt32(d, 20 + (mip + 1) * 4) > 0) mip++;
        int off = BitConverter.ToInt32(d, 20 + mip * 4);
        int mw = Math.Max(1, w >> mip), mh = Math.Max(1, h >> mip);
        var bmp = new Bitmap(mw, mh, PixelFormat.Format32bppArgb);
        if (comp == 2)
        {
            int type = alphaDepth <= 1 ? 1 : (alphaType == 7 ? 5 : 3);
            int blockBytes = type == 1 ? 8 : 16;
            int bw = (mw + 3) / 4, bh = (mh + 3) / 4;
            for (int by = 0; by < bh; by++)
            for (int bx = 0; bx < bw; bx++)
            {
                int p = off + (by * bw + bx) * blockBytes;
                if (p + blockBytes > d.Length) continue;
                int cp = type == 1 ? p : p + 8;
                int c0 = d[cp] | d[cp + 1] << 8, c1 = d[cp + 2] | d[cp + 3] << 8;
                Color[] pal = new Color[4];
                pal[0] = C565(c0); pal[1] = C565(c1);
                if (c0 > c1 || type != 1) { pal[2] = Lerp(pal[0], pal[1], 1, 3); pal[3] = Lerp(pal[0], pal[1], 2, 3); }
                else { pal[2] = Lerp(pal[0], pal[1], 1, 2); pal[3] = Color.Black; }
                uint idx = BitConverter.ToUInt32(d, cp + 4);
                for (int i = 0; i < 16; i++)
                {
                    int x = bx * 4 + (i & 3), y = by * 4 + (i >> 2);
                    if (x >= mw || y >= mh) continue;
                    bmp.SetPixel(x, y, pal[(idx >> (2 * i)) & 3]);
                }
            }
        }
        else if (comp == 1)
        {
            for (int y = 0; y < mh; y++)
            for (int x = 0; x < mw; x++)
            {
                int i = d[off + y * mw + x] * 4;
                bmp.SetPixel(x, y, Color.FromArgb(255, d[148 + i + 2], d[148 + i + 1], d[148 + i]));
            }
        }
        else if (comp == 3)
        {
            for (int y = 0; y < mh; y++)
            for (int x = 0; x < mw; x++)
            {
                int i = off + (y * mw + x) * 4;
                bmp.SetPixel(x, y, Color.FromArgb(255, d[i + 2], d[i + 1], d[i]));
            }
        }
        return bmp;
    }

    // entries: "path|label" lines. Tiles keep their aspect ratio inside `tile` x `tile`.
    public static string Sheet(string listFile, string outPng, int tile, int cols)
    {
        var lines = new List<string>();
        foreach (var l in File.ReadAllLines(listFile)) if (l.Trim().Length > 0) lines.Add(l);
        int rows = (lines.Count + cols - 1) / cols, labelH = 16;
        var sheet = new Bitmap(cols * (tile + 6), rows * (tile + labelH + 6));
        var log = new System.Text.StringBuilder();
        using (var g = Graphics.FromImage(sheet))
        using (var font = new Font("Segoe UI", 8.5f))
        {
            g.Clear(Color.FromArgb(40, 40, 40));
            g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
            for (int n = 0; n < lines.Count; n++)
            {
                var parts = lines[n].Split('|');
                int x0 = (n % cols) * (tile + 6) + 3, y0 = (n / cols) * (tile + labelH + 6) + 3;
                Bitmap b = null;
                try { b = Decode(parts[0], tile * 2); } catch (Exception e) { log.AppendLine(parts[1] + ": " + e.Message); }
                if (b != null)
                {
                    float s = Math.Min((float)tile / b.Width, (float)tile / b.Height);
                    int dw = (int)(b.Width * s), dh = (int)(b.Height * s);
                    g.DrawImage(b, x0, y0, dw, dh);
                    log.AppendLine(parts[1] + ": " + b.Width + "x" + b.Height + " (mip)");
                    b.Dispose();
                }
                else log.AppendLine(parts[1] + ": not decoded");
                g.DrawString(parts[1], font, Brushes.White, x0, y0 + tile + 1);
            }
        }
        sheet.Save(outPng, ImageFormat.Png);
        return log.ToString();
    }
}

public static class BlpGrid
{
    // Each entry rendered at `size` px with a line every 1/16 (labelled in sixteenths) on both axes.
    public static void Grid(string listFile, string outPng, int size, int cols)
    {
        var lines = new System.Collections.Generic.List<string>();
        foreach (var l in File.ReadAllLines(listFile)) if (l.Trim().Length > 0) lines.Add(l);
        int pad = 22, rows = (lines.Count + cols - 1) / cols;
        var sheet = new Bitmap(cols * (size + pad + 8), rows * (size + pad + 20));
        using (var g = Graphics.FromImage(sheet))
        using (var font = new Font("Segoe UI", 7.5f))
        using (var big = new Font("Segoe UI", 9f, FontStyle.Bold))
        using (var pen = new Pen(Color.FromArgb(150, 0, 255, 255)))
        using (var pen4 = new Pen(Color.FromArgb(230, 255, 0, 255)))
        {
            g.Clear(Color.FromArgb(30, 30, 30));
            for (int n = 0; n < lines.Count; n++)
            {
                var parts = lines[n].Split('|');
                int x0 = (n % cols) * (size + pad + 8) + pad, y0 = (n / cols) * (size + pad + 20) + 18;
                var b = BlpSheet.Decode(parts[0], size);
                if (b != null) { g.DrawImage(b, x0, y0, size, size); b.Dispose(); }
                g.DrawString(parts[1], big, Brushes.White, x0, y0 - 16);
                for (int i = 0; i <= 16; i++)
                {
                    int p = i * size / 16;
                    var pn = i % 4 == 0 ? pen4 : pen;
                    g.DrawLine(pn, x0, y0 + p, x0 + size, y0 + p);
                    g.DrawLine(pn, x0 + p, y0, x0 + p, y0 + size);
                    g.DrawString(i.ToString(), font, Brushes.Yellow, x0 - pad + 2, y0 + p - 6);
                }
            }
        }
        sheet.Save(outPng, ImageFormat.Png);
    }
}

public static class BlpAvg
{
    // lines: "key fileId a0 a1 axis" (axis u = horizontal band rows a0..a1 of v; v = vertical strip cols a0..a1 of u)
    public static string Run(string dir, string listFile)
    {
        var sb = new System.Text.StringBuilder();
        foreach (var l in File.ReadAllLines(listFile))
        {
            var p = l.Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
            if (p.Length < 2) continue;
            double a0 = p.Length > 2 ? double.Parse(p[2], System.Globalization.CultureInfo.InvariantCulture) : 0;
            double a1 = p.Length > 3 ? double.Parse(p[3], System.Globalization.CultureInfo.InvariantCulture) : 1;
            string axis = p.Length > 4 ? p[4] : "u";
            var b = BlpSheet.Decode(Path.Combine(dir, p[1] + ".blp"), 128);
            double r = 0, g = 0, bl = 0; int n = 0;
            for (int y = 0; y < b.Height; y++)
            for (int x = 0; x < b.Width; x++)
            {
                double fu = (x + 0.5) / b.Width, fv = (y + 0.5) / b.Height;
                double f = axis == "u" ? fv : fu;
                if (f < a0 || f > a1) continue;
                var c = b.GetPixel(x, y); r += c.R; g += c.G; bl += c.B; n++;
            }
            sb.AppendLine(string.Format(System.Globalization.CultureInfo.InvariantCulture,
                "{0,-22} {{ {1:0.00}, {2:0.00}, {3:0.00} }}", p[0], r / n / 255, g / n / 255, bl / n / 255));
            b.Dispose();
        }
        return sb.ToString();
    }
}
