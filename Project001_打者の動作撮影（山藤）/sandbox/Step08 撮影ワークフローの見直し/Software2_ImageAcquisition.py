# Software 2: Calibration Image Acquisition (for Google Colab)

import cv2
import numpy as np
import os
import matplotlib.pyplot as plt
import ipywidgets as widgets
from IPython.display import display, clear_output
import csv

# ============================================
# 1. Video Info helper
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
# 2. Main UI Class
# ============================================
class CalibImageAcquisitionUI:
    def __init__(self, video_paths, chess_size=(9, 6)):
        self.paths = video_paths
        self.infos = [get_video_info(p) for p in video_paths]
        self.n_frames = min(info["n_frames"] for info in self.infos)
        self.chess_size = chess_size
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
# 3. Validation and Saving
# ============================================
def validate_and_save(video_paths, frames, chess_size, output_dir="calibration_images"):
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
        
    criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 30, 0.001)
    valid_count = 0
    
    for f_idx, f_no in enumerate(frames):
        print(f"Processing Frame {f_no}...")
        cam_frames = []
        success_all = True
        
        for cam_idx, path in enumerate(video_paths):
            cap = cv2.VideoCapture(path)
            cap.set(cv2.CAP_PROP_POS_FRAMES, f_no)
            ret, frame = cap.read()
            cap.release()
            
            if not ret:
                success_all = False
                break
            
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            found, corners = cv2.findChessboardCorners(gray, chess_size)
            
            if found:
                cv2.imwrite(os.path.join(output_dir, f"cam{cam_idx+1}_{valid_count:03d}.jpg"), frame)
            else:
                success_all = False
                print(f"  ❌ Cam {cam_idx+1}: Corners not found")
                break
        
        if success_all:
            valid_count += 1
            print(f"  ✅ Frame {f_no} saved.")
        else:
            # Clean up partial saves if needed
            pass
            
    print(f"\nDone. Saved {valid_count} image sets to {output_dir}/")
