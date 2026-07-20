$ErrorActionPreference = 'Stop'

function RGB([int]$r, [int]$g, [int]$b) {
    return $r + (256 * $g) + (65536 * $b)
}

$C = @{
    Navy = RGB 18 36 64
    Blue = RGB 35 111 161
    Cyan = RGB 42 169 188
    Orange = RGB 235 133 54
    Red = RGB 204 73 69
    Green = RGB 65 145 111
    Ink = RGB 35 42 52
    Muted = RGB 96 108 122
    Pale = RGB 238 244 248
    PaleBlue = RGB 225 239 247
    PaleOrange = RGB 252 238 222
    White = RGB 255 255 255
    Line = RGB 205 216 226
}

function Set-Background($slide, [int]$color) {
    $slide.FollowMasterBackground = 0
    $slide.Background.Fill.Solid()
    $slide.Background.Fill.ForeColor.RGB = $color
}

function Add-Text($slide, [string]$text, [double]$x, [double]$y, [double]$w, [double]$h,
                  [double]$size = 20, [int]$color = 0, [bool]$bold = $false,
                  [int]$align = 1, [string]$font = 'Yu Gothic') {
    $text = $text.Replace('\n', "`n")
    $shape = $slide.Shapes.AddTextbox(1, $x, $y, $w, $h)
    $shape.TextFrame.MarginLeft = 0
    $shape.TextFrame.MarginRight = 0
    $shape.TextFrame.MarginTop = 0
    $shape.TextFrame.MarginBottom = 0
    $shape.TextFrame.WordWrap = -1
    $range = $shape.TextFrame.TextRange
    $range.Text = $text
    $range.Font.Name = $font
    try { $range.Font.NameFarEast = $font } catch {}
    $range.Font.Size = $size
    $range.Font.Bold = $(if ($bold) { -1 } else { 0 })
    $range.Font.Color.RGB = $color
    $range.ParagraphFormat.Alignment = $align
    return $shape
}

function Add-Box($slide, [double]$x, [double]$y, [double]$w, [double]$h,
                 [int]$fill, [int]$line, [double]$radius = 5) {
    $shapeType = $(if ($radius -gt 0) { 5 } else { 1 })
    $shape = $slide.Shapes.AddShape($shapeType, $x, $y, $w, $h)
    $shape.Fill.Solid()
    $shape.Fill.ForeColor.RGB = $fill
    $shape.Line.ForeColor.RGB = $line
    $shape.Line.Weight = 1
    return $shape
}

function Add-Card($slide, [string]$heading, [string]$body, [double]$x, [double]$y,
                  [double]$w, [double]$h, [int]$accent, [double]$bodySize = 17) {
    [void](Add-Box $slide $x $y $w $h $C.White $C.Line)
    $bar = $slide.Shapes.AddShape(1, $x, $y, 7, $h)
    $bar.Fill.Solid(); $bar.Fill.ForeColor.RGB = $accent; $bar.Line.Visible = 0
    [void](Add-Text $slide $heading ($x + 20) ($y + 15) ($w - 35) 28 18 $accent $true)
    [void](Add-Text $slide $body ($x + 20) ($y + 49) ($w - 35) ($h - 60) $bodySize $C.Ink $false)
}

function Add-Arrow($slide, [double]$x1, [double]$y1, [double]$x2, [double]$y2, [int]$color) {
    $line = $slide.Shapes.AddLine($x1, $y1, $x2, $y2)
    $line.Line.ForeColor.RGB = $color
    $line.Line.Weight = 2.5
    $line.Line.EndArrowheadStyle = 3
    return $line
}

function Add-Title($slide, [string]$title, [string]$kicker = '') {
    if ($kicker) {
        [void](Add-Text $slide $kicker 48 25 830 20 11 $C.Blue $true)
    }
    [void](Add-Text $slide $title 48 47 855 50 28 $C.Navy $true)
    $rule = $slide.Shapes.AddShape(1, 48, 102, 68, 4)
    $rule.Fill.Solid(); $rule.Fill.ForeColor.RGB = $C.Orange; $rule.Line.Visible = 0
}

function Add-Footer($slide, [int]$number, [string]$source = 'Aguinaldo et al. (2025), Journal of Sports Sciences') {
    [void](Add-Text $slide $source 48 512 790 15 9 $C.Muted $false)
    [void](Add-Text $slide ([string]$number) 875 509 35 18 10 $C.Muted $true 3)
}

function New-Slide($presentation) {
    $slide = $presentation.Slides.Add($presentation.Slides.Count + 1, 12)
    Set-Background $slide $C.White
    return $slide
}

$ppt = New-Object -ComObject PowerPoint.Application
$presentation = $null
try {
    $ppt.Visible = -1
    $presentation = $ppt.Presentations.Add()
    $presentation.PageSetup.SlideWidth = 960
    $presentation.PageSetup.SlideHeight = 540

    # 1. Title
    $s = New-Slide $presentation
    $left = $s.Shapes.AddShape(1, 0, 0, 610, 540)
    $left.Fill.Solid(); $left.Fill.ForeColor.RGB = $C.Navy; $left.Line.Visible = 0
    $accent = $s.Shapes.AddShape(1, 610, 0, 350, 540)
    $accent.Fill.Solid(); $accent.Fill.ForeColor.RGB = $C.PaleBlue; $accent.Line.Visible = 0
    [void](Add-Text $s '先行研究から、自分の研究へ' 54 80 500 50 31 $C.White $true)
    [void](Add-Text $s '野球投球におけるマーカーレス\nモーションキャプチャの精度検証' 54 155 505 108 26 $C.White $true)
    [void](Add-Text $s '「方法を借りる」＋「限界から課題を立てる」' 56 300 480 32 18 $C.Cyan $true)
    [void](Add-Text $s 'Aguinaldo et al. (2025)\nJournal of Sports Sciences\n\n山藤健太郎｜発表用たたき台｜2026-07-21' 650 98 250 170 16 $C.Ink $false)
    [void](Add-Text $s 'KEY QUESTION' 650 330 200 20 11 $C.Orange $true)
    [void](Add-Text $s 'この論文は、\n自分の研究の\nどこに効くのか？' 650 360 230 100 24 $C.Navy $true)

    # 2. Why this paper
    $s = New-Slide $presentation; Add-Title $s 'なぜ、この先行研究を読むのか' '01｜BACKGROUND'; Add-Footer $s 2
    Add-Card $s '現場のニーズ' '高価な実験室設備や身体マーカーを使わず、競技現場で動作を継続的に測りたい。' 48 135 260 245 $C.Blue 18
    Add-Card $s '残る疑問' '通常の映像から得た3D座標は、どの程度「正しい」のか。特に高速な上肢動作で使えるのか。' 350 135 260 245 $C.Orange 18
    Add-Card $s 'この論文の役割' '球場常設型と可搬型の2種類を、マーカーベース計測と同時比較し、誤差を多段階で評価した。' 652 135 260 245 $C.Green 18
    [void](Add-Arrow $s 309 258 342 258 $C.Muted); [void](Add-Arrow $s 611 258 644 258 $C.Muted)
    [void](Add-Text $s '発表では「便利そう」ではなく、「何を基準に、どの指標で妥当性を示すか」へ話を進める。' 78 425 805 44 20 $C.Navy $true 2)

    # 3. Experimental setup
    $s = New-Slide $presentation; Add-Title $s '比較の設計：3システムを同時に測る' '02｜METHOD'; Add-Footer $s 3
    [void](Add-Box $s 52 137 245 250 $C.PaleBlue $C.Blue)
    [void](Add-Text $s 'Hawk-Eye' 75 158 200 30 22 $C.Blue $true 2)
    [void](Add-Text $s '球場常設型\n5 cameras｜300 Hz\n29 keypoints\n独自のmachine vision＋IK' 75 205 200 125 18 $C.Ink $false 2)
    [void](Add-Text $s 'MARKERLESS' 101 344 145 20 11 $C.Blue $true 2)
    [void](Add-Box $s 357 137 245 250 $C.PaleOrange $C.Orange)
    [void](Add-Text $s 'Marker-based' 380 158 200 30 22 $C.Orange $true 2)
    [void](Add-Text $s '参照基準\n8 cameras｜300 Hz\n38 reflective markers\n関節中心を算出' 380 205 200 125 18 $C.Ink $false 2)
    [void](Add-Text $s 'REFERENCE' 405 344 145 20 11 $C.Orange $true 2)
    [void](Add-Box $s 662 137 245 250 $C.PaleBlue $C.Cyan)
    [void](Add-Text $s 'Theia3D' 685 158 200 30 22 $C.Cyan $true 2)
    [void](Add-Text $s '可搬型\n10 cameras｜300 Hz\n124 salient features\nscaled IK' 685 205 200 125 18 $C.Ink $false 2)
    [void](Add-Text $s 'MARKERLESS' 710 344 145 20 11 $C.Cyan $true 2)
    [void](Add-Arrow $s 300 260 350 260 $C.Orange); [void](Add-Arrow $s 655 260 609 260 $C.Orange)
    [void](Add-Text $s '対象：NCAA男子投手18名｜最大努力の速球｜対応が取れた104球｜平均球速 135.7 ± 6.6 km/h' 72 425 815 40 18 $C.Navy $true 2)

    # 4. Pose models
    $s = New-Slide $presentation; Add-Title $s '姿勢推定モデルは何を使っているか' '03｜POSE ESTIMATION'; Add-Footer $s 4
    Add-Card $s 'Hawk-Eye' '映像\n↓\n独自の機械視覚アルゴリズム\n↓\n29点のキーポイント\n↓\n逆運動学（IK）で骨格モデルへ' 55 135 385 300 $C.Blue 18
    Add-Card $s 'Theia3D' '映像\n↓\nTheia3Dの深層学習モデル\n↓\n124個の特徴点\n↓\n被験者にスケールしたIKモデル' 520 135 385 300 $C.Cyan 18
    [void](Add-Text $s '重要：YOLOを使った研究ではない。学べるのは「検証設計」であり、モデル精度をそのまま自分のYOLO系へ移せない。' 95 463 770 34 16 $C.Red $true 2)

    # 5. MPJPE
    $s = New-Slide $presentation; Add-Title $s 'MPJPEは「何から」の位置誤差か' '04｜PRIMARY METRIC'; Add-Footer $s 5
    [void](Add-Box $s 52 130 410 325 $C.Pale $C.Line)
    [void](Add-Text $s '同じ時刻・同じ関節' 80 150 350 25 18 $C.Navy $true 2)
    $ref = $s.Shapes.AddShape(9, 102, 218, 18, 18); $ref.Fill.Solid(); $ref.Fill.ForeColor.RGB = $C.Orange; $ref.Line.Visible = 0
    $est = $s.Shapes.AddShape(9, 330, 280, 18, 18); $est.Fill.Solid(); $est.Fill.ForeColor.RGB = $C.Blue; $est.Line.Visible = 0
    [void](Add-Text $s 'マーカーベースの関節中心 p' 70 190 250 22 15 $C.Orange $true)
    [void](Add-Text $s 'マーカーレス推定位置 p̂' 292 306 145 42 15 $C.Blue $true 2)
    [void](Add-Arrow $s 124 228 325 279 $C.Red)
    [void](Add-Text $s '3次元の直線距離' 178 238 130 22 15 $C.Red $true 2)
    [void](Add-Text $s 'MPJPE = mean ‖p̂ − p‖₂' 89 375 330 36 23 $C.Navy $true 2)
    [void](Add-Text $s 'この距離を関節・フレーム・試技などで平均' 80 415 350 20 14 $C.Muted $false 2)
    [void](Add-Text $s '全関節平均 MPJPE' 520 142 350 30 20 $C.Navy $true)
    [void](Add-Text $s 'Hawk-Eye' 520 204 120 24 16 $C.Ink $true)
    $b1 = $s.Shapes.AddShape(1, 642, 202, 226, 27); $b1.Fill.Solid(); $b1.Fill.ForeColor.RGB = $C.Blue; $b1.Line.Visible = 0
    [void](Add-Text $s '56.6 mm' 775 205 85 20 14 $C.White $true 3)
    [void](Add-Text $s 'Theia3D' 520 265 120 24 16 $C.Ink $true)
    $b2 = $s.Shapes.AddShape(1, 642, 263, 208, 27); $b2.Fill.Solid(); $b2.Fill.ForeColor.RGB = $C.Cyan; $b2.Line.Visible = 0
    [void](Add-Text $s '52.0 mm' 757 266 85 20 14 $C.White $true 3)
    [void](Add-Text $s '平均すると約5〜6 cmずれた' 520 327 350 34 23 $C.Red $true)
    [void](Add-Text $s '「真の位置」そのものではなく、論文内の参照法であるマーカーベース計測からの差。参照法にも軟部組織アーチファクト等の誤差はある。' 520 380 350 67 15 $C.Muted $false)

    # 6. Joint-specific errors
    $s = New-Slide $presentation; Add-Title $s '平均だけでは見えない：上肢ほど誤差が大きい' '05｜RESULTS'; Add-Footer $s 6
    [void](Add-Text $s '関節' 70 127 80 20 13 $C.Muted $true)
    [void](Add-Text $s '0' 190 127 20 20 11 $C.Muted); [void](Add-Text $s '40' 330 127 25 20 11 $C.Muted); [void](Add-Text $s '80 mm' 484 127 55 20 11 $C.Muted)
    [void](Add-Text $s 'Hawk-Eye' 590 127 90 20 12 $C.Blue $true); [void](Add-Text $s 'Theia3D' 700 127 90 20 12 $C.Cyan $true)
    $joints = @(
        @('股関節',42.9,40.5), @('膝',53.1,44.9), @('足関節',54.1,51.2),
        @('肩',64.3,56.9), @('肘',74.2,70.0), @('手首',71.8,57.1)
    )
    $y = 164
    foreach ($row in $joints) {
        [void](Add-Text $s $row[0] 70 $y 90 23 15 $C.Ink $true)
        $w1 = [double]$row[1] * 4.2; $w2 = [double]$row[2] * 4.2
        $bar1 = $s.Shapes.AddShape(1, 190, $y, $w1, 10); $bar1.Fill.Solid(); $bar1.Fill.ForeColor.RGB = $C.Blue; $bar1.Line.Visible = 0
        $bar2 = $s.Shapes.AddShape(1, 190, ($y + 13), $w2, 10); $bar2.Fill.Solid(); $bar2.Fill.ForeColor.RGB = $C.Cyan; $bar2.Line.Visible = 0
        [void](Add-Text $s ([string]$row[1]) 590 ($y - 1) 70 20 13 $C.Blue $true)
        [void](Add-Text $s ([string]$row[2]) 700 ($y - 1) 70 20 13 $C.Cyan $true)
        $y += 52
    }
    Add-Card $s '読み方' '「全身で約5 cm」だけでは不十分。打撃で重要な肘・手首は平均より大きい。部位別に評価する。' 785 160 135 300 $C.Orange 13

    # 7. Evaluation ladder
    $s = New-Slide $presentation; Add-Title $s '精度評価はMPJPEだけで終わらない' '06｜ANALYSIS PIPELINE'; Add-Footer $s 7
    $steps = @(
        @('1','MPJPE','3D位置の差','mm',$C.Blue),
        @('2','波形RMSE','角度・角速度の差','deg / deg·s⁻¹',$C.Cyan),
        @('3','SPM','波形のどの局面で差が出るか','時系列',$C.Green),
        @('4','Bland–Altman','系統誤差と一致限界','bias / LoA',$C.Orange),
        @('5','CCC','離散値の一致度','−1〜1',$C.Red)
    )
    $x = 50
    foreach ($st in $steps) {
        [void](Add-Box $s $x 155 165 235 $C.White $st[4])
        [void](Add-Text $s $st[0] ($x+15) 170 28 28 18 $C.White $true 2)
        $circle = $s.Shapes.AddShape(9, ($x+10), 165, 38, 38); $circle.Fill.Solid(); $circle.Fill.ForeColor.RGB = $st[4]; $circle.Line.Visible = 0
        [void](Add-Text $s $st[0] ($x+10) 173 38 20 14 $C.White $true 2)
        [void](Add-Text $s $st[1] ($x+20) 222 125 30 18 $st[4] $true 2)
        [void](Add-Text $s $st[2] ($x+17) 270 131 60 15 $C.Ink $false 2)
        [void](Add-Text $s $st[3] ($x+17) 345 131 22 12 $C.Muted $true 2)
        if ($x -lt 746) { [void](Add-Arrow $s ($x+166) 272 ($x+182) 272 $C.Muted) }
        $x += 178
    }
    [void](Add-Text $s '前処理：4次・ゼロ位相・往復 Butterworth フィルタ（18 Hz）' 115 430 730 32 19 $C.Navy $true 2)
    [void](Add-Text $s '18 Hzは参考値。自分の撮影条件では遮断周波数の感度分析が必要。' 170 470 620 22 14 $C.Red $false 2)

    # 8. Waveform results
    $s = New-Slide $presentation; Add-Title $s '位置が近くても、動きの波形が正しいとは限らない' '07｜RESULTS'; Add-Footer $s 8
    [void](Add-Text $s '波形RMSE' 66 130 170 25 17 $C.Navy $true)
    [void](Add-Text $s 'Hawk-Eye' 595 130 100 20 12 $C.Blue $true 2)
    [void](Add-Text $s 'Theia3D' 710 130 100 20 12 $C.Cyan $true 2)
    $metrics = @(
        @('膝関節角度','deg',6.1,2.2),
        @('骨盤回旋角度','deg',6.8,3.4),
        @('肩外旋角度','deg',15.4,16.5),
        @('肩回旋角速度','deg/s',407.9,117.0)
    )
    $y = 170
    foreach ($m in $metrics) {
        [void](Add-Box $s 62 $y 790 58 $C.Pale $C.Line 0)
        [void](Add-Text $s $m[0] 82 ($y+14) 270 25 17 $C.Ink $true)
        [void](Add-Text $s $m[1] 365 ($y+16) 80 20 12 $C.Muted)
        [void](Add-Text $s ([string]$m[2]) 600 ($y+13) 90 25 18 $C.Blue $true 2)
        [void](Add-Text $s ([string]$m[3]) 715 ($y+13) 90 25 18 $C.Cyan $true 2)
        $y += 70
    }
    [void](Add-Text $s '数値微分はノイズと同期ずれを増幅する。位置精度 → 角度 → 角速度の順に検証する。' 82 461 790 32 19 $C.Red $true 2)

    # 9. Limitations
    $s = New-Slide $presentation; Add-Title $s 'この論文の限界は、自分の研究の背景になる' '08｜LIMITATIONS'; Add-Footer $s 9
    Add-Card $s '対象の限定' '男子大学投手18名の速球。打撃、女子、ジュニア、低速動作へ直接一般化できない。' 48 132 270 145 $C.Blue 16
    Add-Card $s 'システム差の混在' 'カメラ台数・配置・距離・推定モデルが異なり、どの要因が誤差を生んだか分離できない。' 345 132 270 145 $C.Orange 16
    Add-Card $s '参照法も完全ではない' 'マーカーベースにも軟部組織アーチファクトや関節中心推定の誤差がある。' 642 132 270 145 $C.Green 16
    Add-Card $s '高速上肢が弱い' '肘・手首の誤差が大きく、遮蔽・ブレ・遠位部の推定が課題になる。' 196 312 270 145 $C.Red 16
    Add-Card $s 'バットは評価外' '人体骨格の検証であり、バット軌道・インパクト時刻・バット速度は保証されない。' 493 312 270 145 $C.Cyan 16

    # 10. Application
    $s = New-Slide $presentation; Add-Title $s '自分の研究では、何を借りて何を解決するか' '09｜CONNECTION TO MY STUDY'; Add-Footer $s 10
    [void](Add-Box $s 50 130 400 320 $C.PaleBlue $C.Blue)
    [void](Add-Text $s 'この論文から借りるもの' 78 153 340 32 22 $C.Blue $true 2)
    [void](Add-Text $s '• 同時計測による参照系との比較\n\n• 部位別MPJPE\n\n• 波形RMSE＋SPM\n\n• Bland–Altman＋CCC\n\n• フィルタ条件の明示' 88 215 320 210 18 $C.Ink $false)
    [void](Add-Box $s 510 130 400 320 $C.PaleOrange $C.Orange)
    [void](Add-Text $s '自分の研究で解決するもの' 538 153 340 32 22 $C.Orange $true 2)
    [void](Add-Text $s '• 2台程度の安価なカメラで成立するか\n\n• 打撃動作でも精度を保てるか\n\n• 上肢・手首の誤差は許容可能か\n\n• 人体とバットを別経路で検出できるか\n\n• 240 fpsの同期ずれを管理できるか' 548 215 320 210 18 $C.Ink $false)
    [void](Add-Text $s '先行研究は「正解」ではなく、自分の研究設計を作るための比較基準。' 130 478 700 25 19 $C.Navy $true 2)

    # 11. Takeaway
    $s = New-Slide $presentation; Add-Title $s '結論：方法だけでも、限界だけでもない' '10｜TAKEAWAY'; Add-Footer $s 11
    [void](Add-Text $s '先行研究の使い方' 65 135 250 28 19 $C.Muted $true)
    $n1 = $s.Shapes.AddShape(9, 72, 190, 72, 72); $n1.Fill.Solid(); $n1.Fill.ForeColor.RGB = $C.Blue; $n1.Line.Visible = 0
    [void](Add-Text $s '1' 72 207 72 35 24 $C.White $true 2)
    [void](Add-Text $s '背景をつくる' 170 185 250 30 23 $C.Navy $true)
    [void](Add-Text $s '現場計測には価値があるが、精度と実用性に未解決点がある。' 170 225 650 35 17 $C.Ink)
    $n2 = $s.Shapes.AddShape(9, 72, 295, 72, 72); $n2.Fill.Solid(); $n2.Fill.ForeColor.RGB = $C.Green; $n2.Line.Visible = 0
    [void](Add-Text $s '2' 72 312 72 35 24 $C.White $true 2)
    [void](Add-Text $s '方法を設計する' 170 290 250 30 23 $C.Navy $true)
    [void](Add-Text $s 'カメラ配置、同期、フィルタ、評価指標を自分の実験計画へ落とす。' 170 330 650 35 17 $C.Ink)
    $n3 = $s.Shapes.AddShape(9, 72, 400, 72, 72); $n3.Fill.Solid(); $n3.Fill.ForeColor.RGB = $C.Orange; $n3.Line.Visible = 0
    [void](Add-Text $s '3' 72 417 72 35 24 $C.White $true 2)
    [void](Add-Text $s '研究課題を絞る' 170 395 250 30 23 $C.Navy $true)
    [void](Add-Text $s '「安価な少数カメラ × 打撃 × 上肢・バット」の妥当性を検証する。' 170 435 650 35 17 $C.Ink)

    $baseName = '03_Aguinaldo2025_先行研究から自分の研究へ'
    $outputDirectory = if ($env:AGUINALDO_PPT_OUTDIR) { $env:AGUINALDO_PPT_OUTDIR } elseif ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $output = Join-Path $outputDirectory ($baseName + '.pptx')
    $version = 2
    while (Test-Path -LiteralPath $output) {
        $output = Join-Path $outputDirectory ($baseName + '_v' + $version + '.pptx')
        $version++
    }
    $presentation.SaveAs($output, 24)
    Write-Output $output
}
finally {
    if ($null -ne $presentation) {
        $presentation.Close()
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($presentation)
    }
    $ppt.Quit()
    [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($ppt)
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}
