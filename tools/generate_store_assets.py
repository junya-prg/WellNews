#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# -----------------------------------------------------------------------------
# 設定
# -----------------------------------------------------------------------------
CANVAS_WIDTH = 1290
CANVAS_HEIGHT = 2796

# ディレクトリパス
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW_DIR = os.path.join(BASE_DIR, 'screenshots', 'raw')
PROCESSED_DIR = os.path.join(BASE_DIR, 'screenshots', 'processed')

# 配色 (Aurora Teal)
BG_GRADIENT_START = (2, 44, 34)  # #022c22
BG_GRADIENT_END = (6, 78, 59)    # #064e3b
TEXT_COLOR = (255, 255, 255)
SUBTEXT_COLOR = (209, 250, 229)  # #d1fae5

# キャッチコピー定義
SCREENSHOT_TEXTS = {
    1: {
        "title": "AIが健康ニュースを要約",
        "subtitle": "最新ニュースの要点のみを瞬時にキャッチ"
    },
    2: {
        "title": "健康ラジオで「ながら聴き」",
        "subtitle": "移動中やウォーキング中も耳から情報インプット"
    },
    3: {
        "title": "関心ワードでパーソナライズ",
        "subtitle": "「睡眠」「サウナ」など気になるワードで自動抽出"
    },
    4: {
        "title": "重要な記事をブックマーク",
        "subtitle": "気になったニュースはいつでもサクッと保存"
    },
    5: {
        "title": "プレミアムプランで制限解除",
        "subtitle": "広告なしの快適な閲覧と、無制限のラジオ再生へ"
    }
}

# -----------------------------------------------------------------------------
# フォントの取得
# -----------------------------------------------------------------------------
def get_font(size, is_bold=False):
    # macOSのシステムフォント候補リスト
    font_paths = [
        "/System/Library/Fonts/Hiragino Sans GB.ttc",
        "/System/Library/Fonts/AppleSDGothicNeo.ttc",
        "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
        "/System/Library/Fonts/HelveticaNeue.ttc",
    ]
    
    for path in font_paths:
        if os.path.exists(path):
            try:
                # TrueType / OpenType コレクションの場合はインデックス指定
                return ImageFont.truetype(path, size)
            except IOError:
                continue
                
    # フォールバック
    return ImageFont.load_default()

# -----------------------------------------------------------------------------
# 背景グラデーションの描画
# -----------------------------------------------------------------------------
def draw_gradient_background(width, height):
    image = Image.new("RGB", (width, height))
    draw = ImageDraw.Draw(image)
    
    # 縦方向のグラデーション
    for y in range(height):
        ratio = y / height
        r = int(BG_GRADIENT_START[0] + (BG_GRADIENT_END[0] - BG_GRADIENT_START[0]) * ratio)
        g = int(BG_GRADIENT_START[1] + (BG_GRADIENT_END[1] - BG_GRADIENT_START[1]) * ratio)
        b = int(BG_GRADIENT_START[2] + (BG_GRADIENT_END[2] - BG_GRADIENT_START[2]) * ratio)
        draw.line([(0, y), (width, y)], fill=(r, g, b))
        
    # 装飾的な背景のボケ円を追加 (モダンデザイン風)
    glow_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_layer)
    
    # 左上と右下にぼんやりした緑の発光
    glow_draw.ellipse([-300, -300, 800, 800], fill=(16, 185, 129, 30))
    glow_draw.ellipse([width - 800, height - 1000, width + 400, height + 200], fill=(52, 211, 153, 20))
    
    # ブラー処理をかけて滑らかに
    glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(120))
    image.paste(glow_layer, (0, 0), glow_layer)
    
    return image

# -----------------------------------------------------------------------------
# デバイスフレームの描画とスクショのはめ込み
# -----------------------------------------------------------------------------
def composite_device(background, screenshot_path):
    try:
        screenshot = Image.open(screenshot_path).convert("RGBA")
    except Exception as e:
        print(f"❌ 画像 {screenshot_path} の読み込みに失敗しました: {e}")
        return None

    # iPhone 16 Pro Max のアスペクト比に基づきデバイスサイズを決定
    device_w = 820
    device_h = 1770
    bezel = 20
    
    screen_w = device_w - 2 * bezel
    screen_h = device_h - 2 * bezel
    
    # スクリーンショットを画面領域サイズにリサイズ
    screenshot_resized = screenshot.resize((screen_w, screen_h), Image.Resampling.LANCZOS)
    
    # 角丸マスクの作成 (スクリーン角丸用)
    screen_mask = Image.new("L", (screen_w, screen_h), 0)
    mask_draw = ImageDraw.Draw(screen_mask)
    mask_draw.rounded_rectangle((0, 0, screen_w, screen_h), radius=90, fill=255)
    
    # デバイス本体のキャンバスを作成 (アルファチャンネルあり)
    device_img = Image.new("RGBA", (device_w, device_h), (0, 0, 0, 0))
    device_draw = ImageDraw.Draw(device_img)
    
    # 1. 外側のベゼル (少しグラファイト/ダークグレーの枠)
    device_draw.rounded_rectangle(
        (0, 0, device_w, device_h),
        radius=120,
        fill=(15, 23, 42, 255),          # #0f172a
        outline=(51, 65, 85, 255),       # #334155
        width=4
    )
    
    # 2. 内側の枠線 (金属的な光沢シミュレーション)
    device_draw.rounded_rectangle(
        (4, 4, device_w - 4, device_h - 4),
        radius=116,
        fill=None,
        outline=(16, 185, 129, 40),      # 緑の薄いリフレクション
        width=2
    )
    
    # 3. スクリーンショットをはめ込み
    screen_pos = (bezel, bezel)
    device_img.paste(screenshot_resized, screen_pos, screen_mask)
    
    # 4. Dynamic Island (上部のカメラ黒カプセル)
    island_w = 280
    island_h = 74
    island_x1 = (device_w - island_w) // 2
    island_y1 = bezel + 14
    device_draw.rounded_rectangle(
        (island_x1, island_y1, island_x1 + island_w, island_y1 + island_h),
        radius=37,
        fill=(0, 0, 0, 255)
    )
    
    # 5. 反射ハイライト (斜めの光沢)
    shine_layer = Image.new("RGBA", (device_w, device_h), (0, 0, 0, 0))
    shine_draw = ImageDraw.Draw(shine_layer)
    # 右上から左下への細い白のグラデーションライン
    shine_draw.polygon([(device_w, 0), (device_w - 180, 0), (0, device_h - 400), (0, device_h - 220)], fill=(255, 255, 255, 8))
    # スクリーン領域の角丸でマスクをかけてデバイス内に閉じる
    device_mask = Image.new("L", (device_w, device_h), 0)
    device_mask_draw = ImageDraw.Draw(device_mask)
    device_mask_draw.rounded_rectangle((0, 0, device_w, device_h), radius=120, fill=255)
    
    device_img = Image.alpha_composite(device_img, shine_layer)
    
    # 背景にデバイスを合成 (X方向中央、下部に配置)
    dest_x = (CANVAS_WIDTH - device_w) // 2
    dest_y = 880  # 上部テキスト用のスペースを十分に空ける
    
    # デバイスに影をつける (3D的な立体感)
    shadow = Image.new("RGBA", (CANVAS_WIDTH, CANVAS_HEIGHT), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    # デバイスより一回り大きい黒のぼかし用矩形を描画
    shadow_draw.rounded_rectangle(
        (dest_x + 10, dest_y + 30, dest_x + device_w - 10, dest_y + device_h + 10),
        radius=120,
        fill=(0, 0, 0, 160)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(35))
    
    background.paste(shadow, (0, 0), shadow)
    background.paste(device_img, (dest_x, dest_y), device_img)

# -----------------------------------------------------------------------------
# テキストの描画
# -----------------------------------------------------------------------------
def draw_text(background, index):
    draw = ImageDraw.Draw(background)
    texts = SCREENSHOT_TEXTS.get(index)
    if not texts:
        return
        
    title = texts["title"]
    subtitle = texts["subtitle"]
    
    # フォントサイズ設定 (1290px幅に適合)
    title_font = get_font(92, is_bold=True)
    subtitle_font = get_font(44, is_bold=False)
    
    # テキストの境界バウンディングボックスを取得
    title_bbox = draw.textbbox((0, 0), title, font=title_font)
    title_w = title_bbox[2] - title_bbox[0]
    
    subtitle_bbox = draw.textbbox((0, 0), subtitle, font=subtitle_font)
    subtitle_w = subtitle_bbox[2] - subtitle_bbox[0]
    
    # 中央揃え座標計算
    title_x = (CANVAS_WIDTH - title_w) // 2
    title_y = 280
    
    subtitle_x = (CANVAS_WIDTH - subtitle_w) // 2
    subtitle_y = 410
    
    # 描画
    draw.text((title_x, title_y), title, fill=TEXT_COLOR, font=title_font)
    draw.text((subtitle_x, subtitle_y), subtitle, fill=SUBTEXT_COLOR, font=subtitle_font)

# -----------------------------------------------------------------------------
# メイン処理
# -----------------------------------------------------------------------------
def main():
    print("🎨 WellNews - App Store用スクリーンショット合成スクリプト")
    
    # ディレクトリ作成
    os.makedirs(RAW_DIR, exist_ok=True)
    os.makedirs(PROCESSED_DIR, exist_ok=True)
    
    # 原稿ファイルの有無をチェック
    raw_files = [f"raw_{i}.png" for i in range(1, 6)]
    missing_files = []
    
    for filename in raw_files:
        filepath = os.path.join(RAW_DIR, filename)
        if not os.path.exists(filepath):
            missing_files.append(filename)
            
    if missing_files:
        print("\n⚠️  未加工のシミュレータ画像が見つかりません。")
        print("以下のフォルダに、Xcodeシミュレータで撮影したスクリーンショットを配置してください：")
        print(f"📂 フォルダパス: {RAW_DIR}")
        print("\n必要なファイル名：")
        for name in raw_files:
            status = "❌ 不足" if name in missing_files else "✅ 準備完了"
            desc = ""
            if "1" in name: desc = " (ニュース一覧)"
            elif "2" in name: desc = " (健康ラジオ再生)"
            elif "3" in name: desc = " (キーワード設定)"
            elif "4" in name: desc = " (ブックマーク画面)"
            elif "5" in name: desc = " (プレミアム画面)"
            print(f"  - {name} {desc}: {status}")
            
        print("\n💡 撮影手順：")
        print("1. Xcode Simulatorで「iPhone 16 Pro Max」等のシミュレータを起動します。")
        print("2. アプリ「WellNews」を開き、対応する画面に遷移します。")
        print("3. キーボードで `Cmd + S` を押すと、Macのデスクトップにスクリーンショット画像が保存されます。")
        print(f"4. それらのファイルを `{RAW_DIR}/raw_1.png` 〜 `raw_5.png` に名前変更して配置してください。")
        print("5. 配置完了後、再度このスクリプトを実行してください。\n")
        return
        
    print("\n🚀 すべての画像が揃っています。合成を開始します...")
    
    for i in range(1, 6):
        raw_name = f"raw_{i}.png"
        raw_path = os.path.join(RAW_DIR, raw_name)
        output_name = f"store_screenshot_{i}.png"
        output_path = os.path.join(PROCESSED_DIR, output_name)
        
        print(f"⏳ {raw_name} を処理中...")
        
        # 1. 背景作成
        canvas = draw_gradient_background(CANVAS_WIDTH, CANVAS_HEIGHT)
        
        # 2. デバイスとはめ込み合成
        composite_device(canvas, raw_path)
        
        # 3. テキスト描画
        draw_text(canvas, i)
        
        # 4. 保存
        canvas.save(output_path, "PNG")
        print(f"✅ 生成完了: {output_path}")
        
    # ウェブの docs/screenshots フォルダへもコピーして同期
    docs_ss_dir = os.path.join(BASE_DIR, 'docs', 'screenshots')
    os.makedirs(docs_ss_dir, exist_ok=True)
    
    for i in range(1, 6):
        src = os.path.join(PROCESSED_DIR, f"store_screenshot_{i}.png")
        dest = os.path.join(docs_ss_dir, f"{i}_news_feed.png" if i==1 else f"{i}_health_radio.png" if i==2 else f"{i}_keywords.png" if i==3 else f"{i}_bookmarks.png" if i==4 else f"{i}_premium.png")
        if os.path.exists(src):
            try:
                Image.open(src).save(dest)
                print(f"➡️  Webサイト用コピー作成: {dest}")
            except Exception as e:
                print(f"⚠️ Web用コピーの作成に失敗しました: {e}")
                
    print("\n🎉 すべてのスクリーンショットの生成が完了しました！")
    print(f"📂 完成品保存先: {PROCESSED_DIR}\n")

if __name__ == "__main__":
    main()
