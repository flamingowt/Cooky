#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
media_resolver.py
Robust resolver for Xiaohongshu (XHS), Douyin, and Direct Video/Image Links.
Supports both Video and Multi-Image (图文笔记) recipes.
"""

import sys
import os
import re
import json
import urllib.request
import urllib.parse
import ssl

ssl_ctx = ssl.create_default_context()
ssl_ctx.check_hostname = False
ssl_ctx.verify_mode = ssl.CERT_NONE

MOBILE_UA = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1'
PC_UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'

def log(msg):
    sys.stderr.write(f"[media_resolver] {msg}\n")
    sys.stderr.flush()

def extract_url(text):
    match = re.search(r'https?://[^\s]+', text)
    if not match:
        return None
    url = match.group(0)
    # clean trailing punctuation
    url = re.sub(r'[\)\]\},，。！？；]+$', '', url)
    return url

def fetch_url(target_url, headers=None, max_redirects=5):
    if headers is None:
        headers = {
            'User-Agent': MOBILE_UA,
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'zh-CN,zh-Hans;q=0.9',
        }
    current_url = target_url
    for _ in range(max_redirects):
        req = urllib.request.Request(current_url, headers=headers)
        try:
            with urllib.request.urlopen(req, context=ssl_ctx, timeout=12) as response:
                content_type = response.headers.get('Content-Type', '')
                data = response.read()
                return current_url, content_type, data
        except urllib.error.HTTPError as e:
            if 300 <= e.code < 400 and 'Location' in e.headers:
                current_url = urllib.parse.urljoin(current_url, e.headers['Location'])
                continue
            raise e
    raise Exception("Too many redirects")

def download_file(file_url, dest_path):
    log(f"Downloading file: {file_url[:80]}... to {dest_path}")
    req = urllib.request.Request(file_url, headers={'User-Agent': MOBILE_UA})
    with urllib.request.urlopen(req, context=ssl_ctx, timeout=30) as response, open(dest_path, 'wb') as out_f:
        while True:
            chunk = response.read(64 * 1024)
            if not chunk:
                break
            out_f.write(chunk)
    file_size = os.path.getsize(dest_path)
    log(f"Download complete: {file_size} bytes")
    return dest_path

def resolve_xhs(html, out_dir, final_url):
    idx = html.find('window.__INITIAL_STATE__=')
    if idx == -1:
        idx = html.find('window.__INITIAL_DATA__=')
    if idx == -1:
        return None

    prefix = html[idx:html.find('=', idx) + 1]
    content = html[idx + len(prefix):]
    end_idx = content.find('</script>')
    if end_idx == -1:
        return None
    raw_json = content[:end_idx].strip()
    if raw_json.endswith(';'):
        raw_json = raw_json[:-1]

    # Clean JavaScript literals (undefined -> null)
    clean_json = raw_json.replace('undefined', 'null')
    try:
        data = json.loads(clean_json)
    except Exception as e:
        log(f"JSON parse error on XHS state: {e}")
        return None

    # Search for real note data
    note = None
    if isinstance(data, dict):
        if 'noteData' in data and isinstance(data['noteData'], dict):
            nd = data['noteData']
            if 'data' in nd and isinstance(nd['data'], dict) and 'noteData' in nd['data']:
                note = nd['data']['noteData']
            elif 'note' in nd:
                note = nd['note']
            else:
                note = nd
        elif 'note' in data and isinstance(data['note'], dict):
            if 'firstNote' in data['note']:
                note = data['note']['firstNote']
            elif 'noteDetailMap' in data['note']:
                map_dict = data['note']['noteDetailMap']
                if map_dict:
                    first_key = list(map_dict.keys())[0]
                    note = map_dict[first_key].get('note')

    if not note or not isinstance(note, dict):
        log("No valid note object found in XHS state")
        return None

    title = note.get('title') or (note.get('desc', '')[:30] if note.get('desc') else '小红书精选菜谱')
    desc = note.get('desc', '')
    note_type = note.get('type')  # 'video' or 'normal'

    log(f"Found XHS Note: Title='{title}', Type='{note_type}'")

    # 1. Video
    if note.get('video') and isinstance(note['video'], dict):
        stream = note['video'].get('media', {}).get('stream', {})
        video_urls = []
        for quality in ['h264', 'h265', 'av1']:
            if quality in stream and isinstance(stream[quality], list):
                for item in stream[quality]:
                    if item.get('masterUrl'):
                        video_urls.append(item['masterUrl'])
        if video_urls:
            dest_video = os.path.join(out_dir, "input_video.mp4")
            download_file(video_urls[0], dest_video)
            return {
                "type": "video",
                "video_path": dest_video,
                "title": title,
                "desc": desc,
                "source_url": final_url
            }

    # 2. Images (图文笔记)
    image_list = note.get('imageList', [])
    if image_list:
        downloaded_images = []
        for i, item in enumerate(image_list):
            img_url = item.get('urlDefault') or item.get('urlOriginal') or item.get('url')
            if img_url:
                dest_img = os.path.join(out_dir, f"img_{i+1:02d}.jpg")
                try:
                    download_file(img_url, dest_img)
                    downloaded_images.append(dest_img)
                except Exception as img_err:
                    log(f"Failed to download image {i+1}: {img_err}")
        if downloaded_images:
            return {
                "type": "images",
                "image_paths": downloaded_images,
                "title": title,
                "desc": desc,
                "source_url": final_url
            }

    return None

def resolve(input_text, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    raw_url = extract_url(input_text)
    if not raw_url:
        return {"error": "未在输入中找到有效链接"}

    log(f"Extracted URL: {raw_url}")

    # 1. Direct Video Link
    clean_url = raw_url.split('?')[0].lower()
    if clean_url.endswith(('.mp4', '.mov', '.m4v', '.webm')):
        video_dest = os.path.join(out_dir, "input_video.mp4")
        download_file(raw_url, video_dest)
        return {
            "type": "video",
            "video_path": video_dest,
            "title": "直链视频",
            "source_url": raw_url
        }

    # 2. Fetch page with Mobile UA first
    try:
        final_url, content_type, data = fetch_url(raw_url, headers={
            'User-Agent': MOBILE_UA,
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'zh-CN,zh-Hans;q=0.9',
        })
        html = data.decode('utf-8', errors='ignore')
    except Exception as e:
        log(f"Fetch error: {e}")
        return {"error": f"无法访问该链接: {e}"}

    # Check WeChat interception
    if "请在微信客户端打开链接" in html:
        return {
            "error": "该链接受微信客户端访问限制（微信专属中转链接）。请在小红书/抖音 App 中点击「分享 -> 复制链接」，或直接上传本地视频/图片测试！"
        }

    # Case A: Xiaohongshu
    if 'xiaohongshu.com' in final_url or 'xhslink.com' in raw_url:
        xhs_result = resolve_xhs(html, out_dir, final_url)
        if xhs_result:
            return xhs_result

    # Case B: Douyin
    if 'douyin.com' in final_url:
        # Regex search for video play address
        mp4_matches = re.findall(r'https?://[^\s"\'>\\]+?(?:\.mp4|\/video\/mp4)[^\s"\'>\\]*', html)
        if mp4_matches:
            dest_video = os.path.join(out_dir, "input_video.mp4")
            download_file(mp4_matches[0], dest_video)
            return {
                "type": "video",
                "video_path": dest_video,
                "title": "抖音烹饪视频",
                "source_url": final_url
            }

    # Fallback: embedded video tags
    video_tag_src = re.findall(r'<video[^>]+src=["\']([^"\']+)["\']', html)
    if video_tag_src:
        v_url = video_tag_src[0]
        if v_url.startswith('//'): v_url = 'https:' + v_url
        dest_video = os.path.join(out_dir, "input_video.mp4")
        try:
            download_file(v_url, dest_video)
            return {
                "type": "video",
                "video_path": dest_video,
                "title": "网页视频",
                "source_url": final_url
            }
        except Exception:
            pass

    return {
        "error": "未能从该分享页提取到公开的音视频/图文媒体（可能触发了平台验证码或防盗链）。建议：直接上传本地视频，或使用页面内置示例体验全流程！"
    }

if __name__ == '__main__':
    if len(sys.argv) < 3:
        sys.stdout.write(json.dumps({"error": "Usage: media_resolver.py <input_text> <out_dir>"}, ensure_ascii=False))
        sys.exit(1)

    text = sys.argv[1]
    out_dir = sys.argv[2]
    result = resolve(text, out_dir)
    # Output pure JSON to stdout
    sys.stdout.write(json.dumps(result, ensure_ascii=False))
    sys.stdout.flush()
