import cv2
import numpy as np
import os
from PIL import Image

def generate_split_charuco():
    output_dir = "output"
    os.makedirs(output_dir, exist_ok=True)
    
    # ==========================================
    # 1. ユーザー設定パラメータ (ここを自由に変更できます)
    # ==========================================
    # ボード全体のマス数 (通常は変更しない)
    total_squares_x = 8
    total_squares_y = 6
    
    # 1枚のA4用紙に収めたいマス数 (今回のご要望: 4x2)
    # A4横置き(297x210mm)に対して横4マス、縦2マス
    a4_squares_x = 4
    a4_squares_y = 2
    
    # A4用紙のサイズ (mm)
    a4_w_mm = 297
    a4_h_mm = 210
    
    # 印刷時の余白(mm) - プリンタが印刷できないフチを考慮
    margin = 10 
    
    # ==========================================
    # 2. 自動計算
    # ==========================================
    # A4用紙の余白を除いた有効エリア
    usable_w = a4_w_mm - (margin * 2)
    usable_h = a4_h_mm - (margin * 2)
    
    # 1マスあたりの最大サイズを計算し、キリの良い整数(mm)にする
    max_sq_w = usable_w / a4_squares_x
    max_sq_h = usable_h / a4_squares_y
    square_length_mm = int(min(max_sq_w, max_sq_h))
    marker_length_mm = int(square_length_mm * 0.75) # マーカーはマスの75%の大きさ
    
    # ボード全体をカバーするために必要なA4用紙の枚数
    sheets_x = int(np.ceil(total_squares_x / a4_squares_x))
    sheets_y = int(np.ceil(total_squares_y / a4_squares_y))
    total_sheets = sheets_x * sheets_y
    
    print("=" * 50)
    print("【自動計算結果】")
    print(f"A4用紙 1枚あたりのマス数: {a4_squares_x} x {a4_squares_y}")
    print(f"マス目のサイズ (square_length): {square_length_mm} mm (0.{square_length_mm:03d} m)")
    print(f"マーカーサイズ (marker_length): {marker_length_mm} mm (0.{marker_length_mm:03d} m)")
    print(f"必要なA4用紙の総枚数: {total_sheets}枚 (横{sheets_x}枚 x 縦{sheets_y}枚)")
    print("=" * 50)
    
    # ==========================================
    # 3. 画像の生成と分割
    # ==========================================
    dpi = 300
    dpmm = dpi / 25.4 
    
    total_w_px = int(total_squares_x * square_length_mm * dpmm)
    total_h_px = int(total_squares_y * square_length_mm * dpmm)
    
    dictionary = cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_4X4_250)
    board = cv2.aruco.CharucoBoard((total_squares_x, total_squares_y), square_length_mm/1000.0, marker_length_mm/1000.0, dictionary)
    board_img = board.generateImage((total_w_px, total_h_px))
    
    # 全体画像の保存
    full_img_path = os.path.join(output_dir, f"charuco_full_{square_length_mm}mm.png")
    Image.fromarray(board_img).save(full_img_path, dpi=(dpi, dpi))
    print(f"\n✅ 全体画像を保存しました: {full_img_path}")
    
    # キャンバスサイズ
    a4_w_px = int(a4_w_mm * dpmm)
    a4_h_px = int(a4_h_mm * dpmm)
    
    count = 1
    for row in range(sheets_y):
        for col in range(sheets_x):
            # 切り出すピクセル範囲の計算
            x_start = int(col * a4_squares_x * square_length_mm * dpmm)
            x_end = int(min((col + 1) * a4_squares_x, total_squares_x) * square_length_mm * dpmm)
            y_start = int(row * a4_squares_y * square_length_mm * dpmm)
            y_end = int(min((row + 1) * a4_squares_y, total_squares_y) * square_length_mm * dpmm)
            
            img_part = board_img[y_start:y_end, x_start:x_end]
            
            # 白紙キャンバスに貼り付け
            a4_canvas = np.ones((a4_h_px, a4_w_px), dtype=np.uint8) * 255
            part_h, part_w = img_part.shape[:2]
            
            y_offset = (a4_h_px - part_h) // 2
            x_offset = (a4_w_px - part_w) // 2
            a4_canvas[y_offset:y_offset+part_h, x_offset:x_offset+part_w] = img_part
            
            filename = os.path.join(output_dir, f"A4_sheet_{count:02d}_row{row+1}_col{col+1}.png")
            Image.fromarray(a4_canvas).save(filename, dpi=(dpi, dpi))
            print(f"✅ 分割画像を保存しました: {filename}")
            count += 1
            
    print("\n【⚠️重要: キャリブレーション時の設定変更】")
    print(f"生成された画像を使う際は、必ずキャリブレーションコード（Step05など）の")
    print(f"パラメータを以下の値に書き換えてください：")
    print(f"  square_length = {square_length_mm/1000.0:.3f}")
    print(f"  marker_length = {marker_length_mm/1000.0:.3f}")

if __name__ == "__main__":
    generate_split_charuco()
