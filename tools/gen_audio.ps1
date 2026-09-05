# gen_audio.ps1 — Synthesizes placeholder SFX for CrickX into assets/audio/.
# Run from the project root:  powershell -File tools\gen_audio.ps1
# All sounds are 16-bit mono PCM WAV at 22050 Hz, generated deterministically.

param([string]$OutDir = "assets\audio")

$sampleRate = 22050
$null = New-Item -ItemType Directory -Force -Path $OutDir
$rand = New-Object System.Random(20260904)

function Write-Wav([string]$Path, [double[]]$Samples) {
    $bytes = New-Object System.Byte[] ($Samples.Count * 2)
    for ($i = 0; $i -lt $Samples.Count; $i++) {
        $s = $Samples[$i]
        if ($s -gt 1.0) { $s = 1.0 } elseif ($s -lt -1.0) { $s = -1.0 }
        $v = [int]([Math]::Round($s * 32767))
        $bytes[2 * $i] = [byte]($v -band 0xFF)
        $bytes[2 * $i + 1] = [byte](($v -shr 8) -band 0xFF)
    }
    $dataLen = $bytes.Length
    $buf = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($buf)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("RIFF"))
    $bw.Write([int](36 + $dataLen))
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("WAVE"))
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("fmt "))
    $bw.Write([int]16)
    $bw.Write([uint16]1)
    $bw.Write([uint16]1)
    $bw.Write([int]$sampleRate)
    $bw.Write([int]($sampleRate * 2))
    $bw.Write([uint16]2)
    $bw.Write([uint16]16)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("data"))
    $bw.Write([int]$dataLen)
    $bw.Write($bytes)
    $bw.Flush()
    [System.IO.File]::WriteAllBytes($Path, $buf.ToArray())
    Write-Host "wrote $Path ($($Samples.Count) samples)"
}

function Get-NoisySample([System.Random]$R) {
    return [double]($R.NextDouble() * 2.0 - 1.0)
}

# ── bat_hit.wav: short noise burst + low thump (~45 ms) ──
$len = [int]($sampleRate * 0.045)
$s = New-Object double[] $len
$lp = 0.0
for ($i = 0; $i -lt $len; $i++) {
    $t = [double]$i / $sampleRate
    $env = [Math]::Exp(-$t * 90.0)
    $noise = Get-NoisySample $rand
    $lp += 0.25 * ($noise - $lp)
    $sine = [Math]::Sin(2.0 * [Math]::PI * 170.0 * $t) * [Math]::Exp(-$t * 55.0)
    $s[$i] = (0.55 * $lp + 0.65 * $sine) * $env * 0.9
}
Write-Wav (Join-Path $OutDir "bat_hit.wav") $s

# ── wicket.wav: two-tone bell (880 -> 659 Hz, ~380 ms) ──
$len = [int]($sampleRate * 0.38)
$s = New-Object double[] $len
$mid = [int]($sampleRate * 0.17)
for ($i = 0; $i -lt $len; $i++) {
    $t = [double]$i / $sampleRate
    if ($i -lt $mid) {
        $f = 880.0
        $local = $t
    } else {
        $f = 659.0
        $local = $t - ($mid / [double]$sampleRate)
    }
    $env = [Math]::Exp(-$local * 8.0)
    $s[$i] = ([Math]::Sin(2.0 * [Math]::PI * $f * $local) * 0.7 + (Get-NoisySample $rand) * 0.08) * $env
}
Write-Wav (Join-Path $OutDir "wicket.wav") $s

# ── crowd_cheer.wav: filtered-noise swell (~1.2 s) ──
$len = [int]($sampleRate * 1.2)
$s = New-Object double[] $len
$lp = 0.0
for ($i = 0; $i -lt $len; $i++) {
    $t = [double]$i / $sampleRate
    $noise = Get-NoisySample $rand
    $lp += 0.08 * ($noise - $lp)
    if ($t -lt 0.15) { $env = $t / 0.15 }
    elseif ($t -gt 0.9) { $env = (1.2 - $t) / 0.3 }
    else { $env = 1.0 }
    $s[$i] = $lp * $env * 1.6
}
Write-Wav (Join-Path $OutDir "crowd_cheer.wav") $s

# ── crowd_ambient.wav: steady low filtered noise, loopable (4 s) ──
$len = [int]($sampleRate * 4.0)
$s = New-Object double[] $len
$lp = 0.0
$fade = [int]($sampleRate * 0.08)
for ($i = 0; $i -lt $len; $i++) {
    $noise = Get-NoisySample $rand
    $lp += 0.05 * ($noise - $lp)
    $env = 1.0
    if ($i -lt $fade) { $env = [double]$i / $fade }
    elseif ($i -ge ($len - $fade)) { $env = [double]($len - $i) / $fade }
    $s[$i] = $lp * $env * 1.2
}
Write-Wav (Join-Path $OutDir "crowd_ambient.wav") $s

# ── ui_click.wav: short 1 kHz blip (~15 ms) ──
$len = [int]($sampleRate * 0.015)
$s = New-Object double[] $len
for ($i = 0; $i -lt $len; $i++) {
    $t = [double]$i / $sampleRate
    $s[$i] = [Math]::Sin(2.0 * [Math]::PI * 1000.0 * $t) * [Math]::Exp(-$t * 220.0) * 0.5
}
Write-Wav (Join-Path $OutDir "ui_click.wav") $s

Write-Host "done."
