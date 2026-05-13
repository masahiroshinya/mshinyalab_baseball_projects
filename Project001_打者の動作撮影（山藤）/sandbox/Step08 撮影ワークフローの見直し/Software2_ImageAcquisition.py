# Software 2: Calibration Image Acquisition (for Google Colab)

import cv2
import numpy as np
import os
import matplotlib.pyplot as plt
import ipywidgets as widgets
from IPython.display import display, clear_output
import csv

# ============================================
# 1. 動画情報取得ヘルパー関数
#    指定された動画ファイルのFPSや解像度、総フレーム数を取得します。
# ============================================
def get_video_info(path):
    cap = cv2.VideoCapture(path)
    if not cap.isOpened():
        return None
    info = {
        "path": path,
        "fps": cap.get(cv2.CAP_PROP_FPS),
        "width": int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)),
        "height": int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT)),
        "n_frames": int(cap.get(cv2.CAP_PROP_FRAME_COUNT)),
    }
    cap.release()
    return info

# ============================================
# 2. UIクラス (フレーム手動選択用)
#    Google Colab上でスライダーを動かし、両方のカメラ映像を並べて見ながら
#    キャリブレーションに使うフレーム（画像）を目視で選ぶためのUIです。
# ============================================
class CalibImageAcquisitionUI:
    def __init__(self, video_paths):
        self.paths = video_paths
        self.infos = [get_video_info(p) for p in video_paths]
        self.n_frames = min(info["n_frames"] for info in self.infos)
        self.selected_frames = []
        self.caps = [cv2.VideoCapture(p) for p in self.paths]
        self.scale = 0.3
        
        # Widgets
        self.slider = widgets.IntSlider(value=0, min=0, max=self.n_frames-1, description='Frame:', layout=widgets.Layout(width='80%'))
        self.btn_select = widgets.Button(description='✅ Select Frame', button_style='success')
        self.btn_undo = widgets.Button(description='↩ Undo', button_style='warning')
        self.status = widgets.HTML()
        self.out = widgets.Output()
        
        self.btn_select.on_click(self.on_select)
        self.btn_undo.on_click(self.on_undo)
        self.slider.observe(self.on_slider_change, names='value')
        
    def get_combined_frame(self, frame_no):
        frames = []
        for cap in self.caps:
            cap.set(cv2.CAP_PROP_POS_FRAMES, frame_no)
            ret, frame = cap.read()
            if ret:
                small = cv2.resize(frame, None, fx=self.scale, fy=self.scale)
                frames.append(cv2.cvtColor(small, cv2.COLOR_BGR2RGB))
        return np.hstack(frames) if frames else None

    def on_slider_change(self, change):
        self.update_display()
        
    def update_display(self):
        with self.out:
            clear_output(wait=True)
            img = self.get_combined_frame(self.slider.value)
            if img is not None:
                plt.figure(figsize=(15, 6))
                plt.imshow(img)
                plt.title(f"Frame: {self.slider.value}")
                plt.axis('off')
                plt.show()

    def on_select(self, _):
        if self.slider.value not in self.selected_frames:
            self.selected_frames.append(self.slider.value)
            self.selected_frames.sort()
        self.update_status()

    def on_undo(self, _):
        if self.selected_frames:
            self.selected_frames.pop()
        self.update_status()

    def update_status(self):
        self.status.value = f"<b>Selected Frames ({len(self.selected_frames)}):</b> {self.selected_frames}"

    def run(self):
        display(self.slider, widgets.HBox([self.btn_select, self.btn_undo]), self.status, self.out)
        self.update_display()
        self.update_status()

# ============================================
# 3. 検証と保存 (メイン処理)
#    UIで選ばれたフレーム番号のリストを受け取り、それぞれのフレームにおいて
#    ChArUcoボードのマーカーが正しく認識できるかを自動判定して保存します。
# ============================================
def validate_and_save(video_paths, frames, output_dir="calibration_images"):
    # 保存先フォルダが存在しない場合は作成
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
        
    # --- ChArUcoボードの設定 ---
    # ここは印刷したボードの実寸（メートル単位）と合わせる必要があります。
    squares_x, squares_y = 8, 6
    square_length = 0.060 # 1マスのサイズ: 60mm (0.06m)
    marker_length = 0.045 # ARマーカーのサイズ: 45mm (0.045m)
    dictionary = cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_4X4_250)
    board = cv2.aruco.CharucoBoard((squares_x, squares_y), square_length, marker_length, dictionary)
    
    valid_count = 0 # 成功して保存したペアの数
    
    # 選択されたフレーム番号を1つずつ処理
    for f_idx, f_no in enumerate(frames):
        print(f"Processing Frame {f_no}...")
        success_all = True
        cam_frames_to_save = []
        
        # 登録されているカメラ（通常は2台）の映像を順番にチェック
        for cam_idx, path in enumerate(video_paths):
            cap = cv2.VideoCapture(path)
            # 指定したフレーム番号までジャンプして画像を1枚読み込む
            cap.set(cv2.CAP_PROP_POS_FRAMES, f_no)
            ret, frame = cap.read()
            cap.release()
            
            if not ret:
                success_all = False
                break
            
            # 画像認識のためにカラー画像を白黒（グレースケール）に変換
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            
            # 1. まずARマーカー（QRコードのような模様）を検出する
            corners, ids, rejected = cv2.aruco.detectMarkers(gray, dictionary)
            
            if ids is not None and len(ids) > 0:
                # 2. 検出したマーカーの位置をもとに、チェスボードの「交点（コーナー）」を計算（補間）する
                retval, charuco_corners, charuco_ids = cv2.aruco.interpolateCornersCharuco(corners, ids, gray, board)
                
                # 3. 検出できた交点の数が「6個以上」あれば、キャリブレーションに使える有効な画像とみなす
                if charuco_corners is not None and len(charuco_corners) >= 6:
                    cam_frames_to_save.append((cam_idx, frame))
                else:
                    success_all = False
                    print(f"  ❌ Cam {cam_idx+1}: 交点が少なすぎます (検出数: {len(charuco_corners) if charuco_corners is not None else 0})")
                    break
            else:
                success_all = False
                print(f"  ❌ Cam {cam_idx+1}: マーカーが一つも検出されませんでした")
                break
        
        if success_all:
            # 両方のカメラで条件（交点6個以上）をクリアした場合のみ、画像を保存する
            for cam_idx, frame in cam_frames_to_save:
                # ファイル名は「cam1_000.jpg」「cam2_000.jpg」のように連番になる
                cv2.imwrite(os.path.join(output_dir, f"cam{cam_idx+1}_{valid_count:03d}.jpg"), frame)
            valid_count += 1
            print(f"  ✅ Frame {f_no} saved.")
        else:
            # どちらかのカメラで失敗した場合は、そのフレームは破棄される
            pass
            
    print(f"\nDone. Saved {valid_count} image sets to {output_dir}/")
