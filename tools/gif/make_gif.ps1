param([string]$Video, [string]$Out, [int]$Width = 720, [int]$Fps = 10, [int]$Threshold = 12)
$ErrorActionPreference = "Stop"
$SP = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$SP\winrt.ps1"
Add-Type -AssemblyName System.Drawing
if (-not ("GifWriter" -as [type])) { Add-Type -Path "$SP\GifWriter.cs" -ReferencedAssemblies System.Drawing }

$c = Open-Clip $Video
$dur = $c.Comp.Duration.TotalSeconds
$n = [math]::Floor($dur * $Fps)
$frames = New-Object System.Collections.Generic.List[System.Drawing.Bitmap]
for ($i = 0; $i -lt $n; $i++) {
    $t = [TimeSpan]::FromSeconds($i / $Fps)
    $img = Await ($c.Comp.GetThumbnailAsync($t, $Width, 0, [Windows.Media.Editing.VideoFramePrecision]::NearestFrame)) ([Windows.Graphics.Imaging.ImageStream])
    $s = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($img)
    $src = [System.Drawing.Image]::FromStream($s)
    $bmp = New-Object System.Drawing.Bitmap $src.Width, $src.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp); $g.DrawImage($src, 0, 0, $src.Width, $src.Height); $g.Dispose(); $src.Dispose()
    $frames.Add($bmp)
}
$bytes = [GifWriter]::Write($Out, $frames.ToArray(), [int](100 / $Fps), $Threshold)
"{0} frames, {1}x{2} @ {3} fps -> {4:N2} MB" -f $frames.Count, $frames[0].Width, $frames[0].Height, $Fps, ($bytes / 1MB)
