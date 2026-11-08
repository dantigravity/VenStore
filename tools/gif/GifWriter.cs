// Minimal animated GIF encoder: global median-cut palette (255 colours + 1 transparent),
// frame differencing (unchanged pixels transparent, frames cropped to the changed rectangle),
// LZW compression, infinite loop.
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class GifWriter
{
    const int TRANSPARENT = 255;

    static int[] Pixels(Bitmap b)
    {
        var data = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        var px = new int[b.Width * b.Height];
        for (int y = 0; y < b.Height; y++)
            Marshal.Copy(data.Scan0 + y * data.Stride, px, y * b.Width, b.Width);
        b.UnlockBits(data);
        return px;
    }

    // ---- palette: median cut over a 15-bit colour histogram
    class Box { public List<int> Colors; }
    static int[] BuildPalette(List<int[]> frames, int maxColors)
    {
        var hist = new int[32768];
        foreach (var f in frames)
            for (int i = 0; i < f.Length; i += 3)
            {
                int c = f[i];
                hist[((c >> 19) & 31) << 10 | ((c >> 11) & 31) << 5 | ((c >> 3) & 31)]++;
            }
        var all = new List<int>();
        for (int i = 0; i < 32768; i++) if (hist[i] > 0) all.Add(i);
        var boxes = new List<Box> { new Box { Colors = all } };
        while (boxes.Count < maxColors)
        {
            Box best = null; int bestRange = -1, bestCh = 0;
            foreach (var b in boxes)
            {
                if (b.Colors.Count < 2) continue;
                for (int ch = 0; ch < 3; ch++)
                {
                    int lo = 31, hi = 0;
                    foreach (var c in b.Colors) { int v = (c >> (10 - ch * 5)) & 31; if (v < lo) lo = v; if (v > hi) hi = v; }
                    // weight by population so busy regions get more colours
                    long pop = 0; foreach (var c in b.Colors) pop += hist[c];
                    int score = (int)((hi - lo) * Math.Sqrt(pop));
                    if (score > bestRange) { bestRange = score; best = b; bestCh = ch; }
                }
            }
            if (best == null || bestRange <= 0) break;
            int shift = 10 - bestCh * 5;
            best.Colors.Sort((a, b2) => ((a >> shift) & 31).CompareTo((b2 >> shift) & 31));
            long total = 0; foreach (var c in best.Colors) total += hist[c];
            long acc = 0; int cut = 1;
            for (int i = 0; i < best.Colors.Count - 1; i++) { acc += hist[best.Colors[i]]; if (acc >= total / 2) { cut = i + 1; break; } }
            var second = new Box { Colors = best.Colors.GetRange(cut, best.Colors.Count - cut) };
            best.Colors = best.Colors.GetRange(0, cut);
            boxes.Add(second);
        }
        var pal = new int[boxes.Count];
        for (int k = 0; k < boxes.Count; k++)
        {
            long r = 0, g = 0, b = 0, n = 0;
            foreach (var c in boxes[k].Colors) { int w = hist[c]; r += ((c >> 10) & 31) * w; g += ((c >> 5) & 31) * w; b += (c & 31) * w; n += w; }
            if (n == 0) n = 1;
            pal[k] = (int)(r * 255 / (31 * n)) << 16 | (int)(g * 255 / (31 * n)) << 8 | (int)(b * 255 / (31 * n));
        }
        return pal;
    }

    static byte[] MapLookup(int[] pal)
    {
        var map = new byte[32768];
        for (int i = 0; i < 32768; i++)
        {
            int r = ((i >> 10) & 31) * 255 / 31, g = ((i >> 5) & 31) * 255 / 31, b = (i & 31) * 255 / 31;
            int best = 0, bestD = int.MaxValue;
            for (int k = 0; k < pal.Length; k++)
            {
                int dr = r - ((pal[k] >> 16) & 255), dg = g - ((pal[k] >> 8) & 255), db = b - (pal[k] & 255);
                int d = 3 * dr * dr + 4 * dg * dg + 2 * db * db;
                if (d < bestD) { bestD = d; best = k; }
            }
            map[i] = (byte)best;
        }
        return map;
    }

    // ---- LZW
    static void WriteLzw(BinaryWriter w, byte[] idx)
    {
        const int minCode = 8;
        w.Write((byte)minCode);
        var buf = new List<byte>();
        int bitBuf = 0, bitCnt = 0;
        int clear = 1 << minCode, eoi = clear + 1, next = eoi + 1, size = minCode + 1;
        var dict = new Dictionary<int, int>();
        Action<int> emit = code =>
        {
            bitBuf |= code << bitCnt; bitCnt += size;
            while (bitCnt >= 8) { buf.Add((byte)(bitBuf & 255)); bitBuf >>= 8; bitCnt -= 8; }
        };
        emit(clear);
        int prefix = idx.Length > 0 ? idx[0] : 0;
        for (int i = 1; i < idx.Length; i++)
        {
            int k = idx[i];
            int key = (prefix << 8) | k;
            int code;
            if (dict.TryGetValue(key, out code)) { prefix = code; continue; }
            emit(prefix);
            if (next < 4096)
            {
                dict[key] = next++;
                if (next > (1 << size) && size < 12) size++;
            }
            else
            {
                emit(clear);
                dict.Clear(); next = eoi + 1; size = minCode + 1;
            }
            prefix = k;
        }
        emit(prefix);
        emit(eoi);
        if (bitCnt > 0) buf.Add((byte)(bitBuf & 255));
        for (int i = 0; i < buf.Count; i += 255)
        {
            int n = Math.Min(255, buf.Count - i);
            w.Write((byte)n);
            w.Write(buf.ToArray(), i, n);
        }
        w.Write((byte)0);
    }

    public static long Write(string path, Bitmap[] frames, int delayCs, int threshold)
    {
        int W = frames[0].Width, H = frames[0].Height;
        var px = new List<int[]>();
        foreach (var f in frames) px.Add(Pixels(f));
        var sample = new List<int[]>();
        for (int i = 0; i < px.Count; i += Math.Max(1, px.Count / 12)) sample.Add(px[i]);
        var pal = BuildPalette(sample, 255);
        var map = MapLookup(pal);

        using (var fs = new FileStream(path, FileMode.Create))
        using (var w = new BinaryWriter(fs))
        {
            w.Write(new[] { (byte)'G', (byte)'I', (byte)'F', (byte)'8', (byte)'9', (byte)'a' });
            w.Write((short)W); w.Write((short)H);
            w.Write((byte)0xF7); w.Write((byte)0); w.Write((byte)0); // global table, 256 entries
            for (int k = 0; k < 256; k++)
            {
                int c = k < pal.Length ? pal[k] : 0;
                w.Write((byte)((c >> 16) & 255)); w.Write((byte)((c >> 8) & 255)); w.Write((byte)(c & 255));
            }
            // loop forever
            w.Write((byte)0x21); w.Write((byte)0xFF); w.Write((byte)11);
            w.Write(System.Text.Encoding.ASCII.GetBytes("NETSCAPE2.0"));
            w.Write((byte)3); w.Write((byte)1); w.Write((short)0); w.Write((byte)0);

            int[] shown = null; // colours currently on screen (after quantising)
            int lastDelay = 0; long lastDelayPos = -1;
            for (int f = 0; f < px.Count; f++)
            {
                var cur = px[f];
                var q = new int[W * H];
                for (int i = 0; i < cur.Length; i++)
                {
                    int c = cur[i];
                    q[i] = map[((c >> 19) & 31) << 10 | ((c >> 11) & 31) << 5 | ((c >> 3) & 31)];
                }
                int x0 = 0, y0 = 0, x1 = W - 1, y1 = H - 1;
                bool[] changed = null;
                if (shown != null)
                {
                    changed = new bool[W * H];
                    x0 = W; y0 = H; x1 = -1; y1 = -1;
                    for (int y = 0; y < H; y++)
                        for (int x = 0; x < W; x++)
                        {
                            int i = y * W + x;
                            if (q[i] == shown[i]) continue;
                            // ignore tiny colour flicker between near-identical palette entries
                            int a = pal[q[i]], b = pal[shown[i]];
                            int d = Math.Abs(((a >> 16) & 255) - ((b >> 16) & 255)) + Math.Abs(((a >> 8) & 255) - ((b >> 8) & 255)) + Math.Abs((a & 255) - (b & 255));
                            if (d <= threshold) continue;
                            changed[i] = true;
                            if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y;
                        }
                    if (x1 < 0) // identical frame: show the previous one longer
                    {
                        lastDelay += delayCs;
                        w.Flush(); long pos = fs.Position;
                        fs.Seek(lastDelayPos, SeekOrigin.Begin); w.Write((short)lastDelay); w.Flush();
                        fs.Seek(pos, SeekOrigin.Begin);
                        continue;
                    }
                }
                if (shown == null) shown = new int[W * H];
                int rw = x1 - x0 + 1, rh = y1 - y0 + 1;
                var idx = new byte[rw * rh];
                for (int y = 0; y < rh; y++)
                    for (int x = 0; x < rw; x++)
                    {
                        int i = (y0 + y) * W + (x0 + x);
                        if (changed != null && !changed[i]) { idx[y * rw + x] = TRANSPARENT; continue; }
                        idx[y * rw + x] = (byte)q[i];
                        shown[i] = q[i];
                    }
                // graphic control: delay, disposal = leave in place, transparent index
                w.Write((byte)0x21); w.Write((byte)0xF9); w.Write((byte)4);
                w.Write((byte)(0x04 | 0x01));
                w.Flush(); lastDelayPos = fs.Position; lastDelay = delayCs;
                w.Write((short)delayCs); w.Write((byte)TRANSPARENT); w.Write((byte)0);
                w.Write((byte)0x2C); w.Write((short)x0); w.Write((short)y0); w.Write((short)rw); w.Write((short)rh); w.Write((byte)0);
                WriteLzw(w, idx);
            }
            w.Write((byte)0x3B);
            return fs.Length;
        }
    }
}
