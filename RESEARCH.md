# yt-dlp Research & Documentation

## 1. Core Capabilities

### Content Types Supported
yt-dlp is a universal content downloader that works with 1000+ extractors, supporting:

- **Video Files**: MP4, WebM, MKV, AVI, FLV, MOV formats
- **Audio Extraction**: Extract audio from videos, save as MP3, AAC, FLAC, Opus, WAV, M4A, ALAC, Vorbis
- **Playlists**: Full playlist downloads with filtering (start, stop, range selection)
- **Channels**: Channel subscriptions and archive downloads
- **Livestreams**: Download active livestreams or scheduled streams (YouTube, Twitch)
- **Subtitles**: Automatic & manual captions in multiple languages
- **Thumbnails**: Video thumbnails in multiple formats (PNG, JPG, WebP)
- **Metadata**: Title, description, duration, uploader, upload date, view count, etc.

### Supported Sites (1000+)
- YouTube (most comprehensive support)
- Twitch (streams, VODs, clips)
- TikTok, Instagram, Facebook
- Twitter/X, Reddit
- Dailymotion, Vimeo, Bilibili
- And 1000+ other sites

---

## 2. Main Configuration Parameters for UI

### Format & Quality Selection

```bash
# List available formats (without downloading)
yt-dlp -F <URL>

# Format IDs: "format_id" from format list
# Examples:
yt-dlp -f "bestvideo+bestaudio/best" <URL>      # Best video+audio combo
yt-dlp -f "bestvideo[height<=480]+bestaudio" <URL> # Best video up to 480p
yt-dlp -f "worst/worstvideo+worstaudio" <URL>    # Lowest quality (smallest file)
```

**Key Parameters:**
- `-f, --format FORMAT`: Specify format by ID or combination
- `-S, --format-sort SORTORDER`: Sort formats by quality, fps, codec, etc.
- `--merge-output-format FORMAT`: Container for merging (mp4, mkv, webm, avi, flv, mov)
- `--check-formats`: Verify formats are actually downloadable before proceeding
- `-F, --list-formats`: Simulate and show available formats only

**Format Sorting Options:**
- `video` - quality, resolution, fps
- `audio` - bitrate (abr), codec (acodec), sample rate (asr)
- `ext` - video container extension
- Examples: `-S "vcodec:h264,res,fps,acodec:aac"`

### Audio Extraction

```bash
# Extract audio only and convert to MP3
yt-dlp -x --audio-format mp3 <URL>

# Extract as AAC (highest quality)
yt-dlp -x --audio-format aac <URL>

# Select specific audio quality
yt-dlp -x --audio-format mp3 --audio-quality 0 <URL>  # Best quality
yt-dlp -x --audio-format mp3 --audio-quality 5 <URL>  # Medium (default)
yt-dlp -x --audio-format mp3 --audio-quality 10 <URL> # Worst quality
```

**Parameters:**
- `-x, --extract-audio`: Convert to audio-only
- `--audio-format FORMAT`: mp3, aac, flac, m4a, opus, vorbis, wav, alac
- `--audio-quality QUALITY`: VBR 0-10 (0=best, 10=worst) or bitrate like "128K"
- `--remux-video FORMAT`: Remux video without re-encoding
- `--recode-video FORMAT`: Re-encode to different format (slower, higher quality control)

### Output & File Naming

```bash
# Default: %(title)s.%(ext)s
# Custom template with variables
yt-dlp -o "%(uploader)s - %(title)s.%(ext)s" <URL>
yt-dlp -o "downloads/%(playlist)s/%(playlist_index)s - %(title)s.%(ext)s" <URL>

# Preset aliases for quick conversion
yt-dlp -t mp3 <URL>        # Quick alias for mp3 extraction
yt-dlp -t aac <URL>        # AAC extraction
yt-dlp -t mp4 <URL>        # MP4 optimization
yt-dlp -t mkv <URL>        # MKV container
```

**Parameters:**
- `-o, --output TEMPLATE`: Output filename template
- `--paths TYPE:TEMPLATE`: Set output paths for different file types
- `-P, --paths PATH`: Prepend path to all output files

**Common Template Variables:**
- `%(title)s` - Video title
- `%(uploader)s` - Channel/creator name
- `%(ext)s` - File extension
- `%(duration)s` - Video duration in seconds
- `%(upload_date)s` - YYYYMMDD format
- `%(view_count)s` - View count
- `%(width)s`, `%(height)s` - Video dimensions
- `%(fps)s` - Frames per second
- `%(playlist)s` - Playlist name
- `%(playlist_index)s` - Position in playlist
- `%(id)s` - Video ID

### Subtitle Downloading

```bash
# Download subtitles
yt-dlp --write-subs --sub-format "srt" <URL>

# Auto-generated captions (all languages)
yt-dlp --write-auto-subs --sub-langs "en" <URL>

# Multiple subtitle languages
yt-dlp --write-subs --sub-langs "en,fr,de" <URL>

# List available subtitles first
yt-dlp --list-subs <URL>
```

**Parameters:**
- `--write-subs`: Download available subtitles
- `--write-auto-subs`: Download auto-generated captions
- `--list-subs`: Show available subtitles (simulate mode)
- `--sub-format FORMAT`: vtt, srt, ass, ttml, srv1/2/3, json3
- `--sub-langs LANGS`: Language codes or "all", regex supported
- `--embed-subs`: Embed subtitles in video (MP4, WebM, MKV only)
- `--convert-subs FORMAT`: Convert subtitles to different format
- `--skip-unavailable-fragments`: Skip if subtitles unavailable

### Playlist Handling

```bash
# Download full playlist
yt-dlp "https://www.youtube.com/playlist?list=..."

# Download specific items
yt-dlp -I "1:10" <playlist_url>        # Items 1-10
yt-dlp -I "1,5,10" <playlist_url>      # Items 1, 5, 10
yt-dlp -I "1::2" <playlist_url>        # Every 2nd item starting from 1

# Flatten playlists
yt-dlp --no-playlist <URL>              # Download only single video if mixed
yt-dlp --yes-playlist <URL>             # Force playlist download

# Playlist metadata
yt-dlp -I "1" --dump-json <URL> | jq . # Get first item info
```

**Parameters:**
- `-I, --playlist-items ITEM_SPEC`: Comma-separated or range selection
- `--no-playlist`: Download only the video, ignore playlist
- `--yes-playlist`: Force download entire playlist if URL is mixed
- `--flat-playlist`: Fast mode (limited metadata)
- `--break-on-existing`: Stop at first file that exists
- `--skip-playlist-after-errors N`: Skip rest of playlist after N errors

### Concurrent Downloads

```bash
# Fragment-level concurrency (for dash/hls)
yt-dlp -N 4 <URL>  # 4 concurrent fragments

# Note: yt-dlp processes videos sequentially by default
# For true parallel video downloads, use external tools or scripting
```

**Parameters:**
- `-N, --concurrent-fragments N`: Fragments to download concurrently (default: 1)
- Works with DASH, HLS, and ISM streams
- Not for multiple videos (process one at a time)

### Error Handling & Retries

```bash
# Retry on network errors
yt-dlp -R 10 <URL>                 # Retry 10 times (default)
yt-dlp -R infinite <URL>           # Infinite retries
yt-dlp -R 3 <URL>                  # Retry 3 times

# Continue on errors (for playlists)
yt-dlp --ignore-errors <URL>              # Skip failed videos
yt-dlp --no-abort-on-error <URL>          # Default behavior
yt-dlp --abort-on-error <URL>             # Stop on first error

# Fragment retry (HLS/DASH)
yt-dlp --fragment-retries 10 <URL>
yt-dlp --skip-unavailable-fragments <URL>

# Rate limiting
yt-dlp -r 500K <URL>               # Max 500KB/s download speed
yt-dlp --throttled-rate 100K <URL> # Detect throttling at <100KB/s
```

**Parameters:**
- `-R, --retries RETRIES`: HTTP retries (default: 10)
- `--fragment-retries RETRIES`: Fragment retries (default: 10)
- `--file-access-retries RETRIES`: File access retries (default: 3)
- `--retry-sleep [TYPE:]EXPR`: Sleep duration between retries
- `-r, --limit-rate RATE`: Max download speed (e.g., 50K, 4.2M)
- `--socket-timeout SECONDS`: Connection timeout
- `--ignore-errors`: Continue on download errors
- `--abort-on-error`: Stop on first error
- `--no-abort-on-error`: Default, continue on errors

### Post-Processing Options

```bash
# Convert to MP4 with H.264 video
yt-dlp --remux-video "mp4" <URL>

# Re-encode to specific quality
yt-dlp --recode-video "mp4" <URL>

# Embed subtitles in video
yt-dlp --write-subs --embed-subs <URL>

# Embed thumbnail
yt-dlp --write-thumbnail --embed-thumbnail <URL>

# Keep intermediate files
yt-dlp -k <URL>  # Keep video after post-processing

# SponsorBlock integration (remove ads/intro/outro)
yt-dlp --sponsorblock-remove "sponsor,intro,outro" <URL>
```

**Parameters:**
- `--remux-video FORMAT`: Remux without re-encoding
- `--recode-video FORMAT`: Full re-encode
- `--embed-subs`: Embed subtitles (MP4, WebM, MKV)
- `--embed-thumbnail`: Embed thumbnail as cover art
- `--embed-metadata`: Add metadata to file
- `--embed-chapters`: Add chapter markers
- `-k, --keep-video`: Keep intermediate files
- `--post-overwrites`: Overwrite post-processed files (default)
- `--sponsorblock-mark CATS`: Mark sponsor segments as chapters
- `--sponsorblock-remove CATS`: Remove SponsorBlock segments

---

## 3. Output & Progress Streaming

### Progress Reporting

**stdout/stderr Output Structure:**
```
[extractor] Source: Extracting URL
[extractor] Video_ID: Downloading webpage
[extractor] Video_ID: Downloading format list
[download] Video Title has already been downloaded
[download] Downloading video 1 of 1
[download] Video Title
  0.2% at 125.45KiB/s ETA 00:05:30
[ffmpeg] Merging formats into "output.mp4"
[ffmpeg] Deleting intermediate file "video.f248.webm"
```

**Progress Information Available:**
- `_now_str`: Timestamp in HH:MM:SS format
- `_duration_str`: Total duration in HH:MM:SS
- `_total_bytes_str`: Total file size
- `_downloaded_bytes_str`: Downloaded so far
- `_speed_str`: Current download speed
- `_eta_str`: Estimated time remaining
- `_percent_str`: Progress percentage
- Download state: downloading, already downloaded, skipped, error

### Progress Template Customization

```bash
# Show custom progress output
yt-dlp --progress-template \
  'download:%(progress._percent_str)s at %(progress._speed_str)s ETA %(progress._eta_str)s' \
  <URL>

# Newline instead of carriage return (for logging)
yt-dlp --newline <URL>

# Console title with current download
yt-dlp --console-title <URL>

# Progress delta (update frequency)
yt-dlp --progress-delta 1 <URL>  # Update every 1 second (default: 0 = every time)
```

**Parameters:**
- `--progress-template TEMPLATE`: Custom progress output format
- `--progress-delta SECONDS`: Update frequency (default: 0)
- `--newline`: Output progress as newlines instead of overwrite
- `--console-title`: Show progress in terminal title
- `--no-progress`: Suppress progress bar

### Capturing Output

**yt-dlp writes to:**
- `stdout`: Regular info messages, progress
- `stderr`: Errors and warnings
- Can redirect: `yt-dlp <URL> 2>&1` to capture both

**Parseable Output:**
```bash
# JSON info dump
yt-dlp --dump-json <URL> | jq .

# Quiet mode (only errors)
yt-dlp -q <URL>

# Verbose mode
yt-dlp -v <URL>

# Write to file
yt-dlp --output "downloads/%(title)s.%(ext)s" <URL>
```

**Parameters:**
- `--dump-json`: Output complete info as JSON
- `-q, --quiet`: Suppress output (errors only)
- `-v, --verbose`: Verbose output with debug info
- `-s, --simulate`: Dry run, show what would be downloaded
- `--no-progress`: Suppress progress bar
- `-q --no-warnings`: Minimal output

### Exit Codes

```
0  - Successful download
1  - General errors (network, missing file, etc.)
2  - Download error for specific video
3  - FileDownload error
4  - File I/O error
5  - Post-processing error
101+ - Errors in extractors or plugins
```

**Error Handling in Code:**
- Exit code 0: Success
- Exit code 1: Command-line usage error or general failure
- Exit code 2: Download failed but playlist continued
- Check `--abort-on-error` for failure modes

---

## 4. Configuration System

### Config Files Support

**Locations (checked in order):**
```
1. ~/.config/yt-dlp/config           (Linux/macOS)
   %APPDATA%/yt-dlp/config           (Windows)
2. ~/.config/yt-dlp/config.txt
3. /etc/yt-dlp/config                (System-wide)
4. Working directory: yt-dlp.conf
```

**Config File Format:**
```ini
# Global options (apply to all downloads)
output=downloads/%(title)s.%(ext)s
format=bestvideo+bestaudio/best
sub-langs=en,fr,de
write-subs=True

# Category options
[youtube]
output=youtube/%(playlist)s/%(title)s.%(ext)s

[twitch]
output=streams/%(uploader)s - %(title)s.%(ext)s
```

**Command-line Override:**
```bash
# CLI options override config file
yt-dlp --ignore-config <URL>              # Ignore config file
yt-dlp --config-locations <path> <URL>    # Use specific config
yt-dlp --no-config-locations <URL>        # No config file
```

**Parameters:**
- `--ignore-config`: Don't load config files
- `--config-locations PATH`: Use specific config file(s)
- `--no-config-locations`: No config files
- `--load-info-json FILE`: Load cached info from previous run

### CLI Parameters

**All parameters can be passed via command-line:**
```bash
yt-dlp \
  --format "bestvideo+bestaudio" \
  --output "downloads/%(title)s.%(ext)s" \
  --write-subs \
  --sub-langs "en" \
  --retries 5 \
  --playlist-items "1:10" \
  <URL>
```

### Rate Limiting & Concurrency

```bash
# Fragment concurrency (HLS/DASH)
yt-dlp -N 4 <URL>

# Download rate limiting
yt-dlp -r 500K <URL>                    # Max 500 KB/s
yt-dlp --throttled-rate 100K <URL>      # Detect throttle at <100KB/s

# Request sleep (politeness)
yt-dlp --sleep-interval 1 <URL>         # 1 second between requests
yt-dlp --max-sleep-interval 60 <URL>    # Max sleep of 60 seconds

# Connection timeout
yt-dlp --socket-timeout 30 <URL>        # 30 second timeout
```

**Parameters:**
- `-N, --concurrent-fragments N`: Concurrent fragment downloads
- `-r, --limit-rate RATE`: Max download rate
- `--sleep-interval SECONDS`: Sleep between requests
- `--max-sleep-interval SECONDS`: Maximum sleep duration
- `--socket-timeout SECONDS`: Connection timeout

---

## 5. Key Parameters for UI Implementation

### Essential Parameters (Minimum UI)
1. **URL**: Video/playlist URL
2. **Format**: Quality selection (best, worst, 720p, 480p, audio-only)
3. **Output Path**: Where to save files
4. **Subtitles**: Yes/no toggle
5. **Audio Only**: Extract audio checkbox

### Recommended Parameters (Full UI)
1. **URL(s)**: Single or batch
2. **Format/Quality**:
   - Preset: Best, Good, Medium, Low, Audio Only
   - Custom: Format selector from `-F` list
3. **Output**:
   - Path selection
   - Filename template
4. **Subtitles**:
   - Enabled/disabled
   - Language selection (regex support)
   - Format (SRT, VTT, etc.)
5. **Playlist**:
   - Download entire or items selection
   - Item range (1:10, 1::2)
6. **Download**:
   - Concurrent fragments (1-4)
   - Rate limiting
   - Retries
7. **Post-Processing**:
   - Audio conversion
   - Format remuxing
   - SponsorBlock removal
8. **Advanced**:
   - Custom output template
   - Config file loading
   - Proxy support

### Progress Monitoring
- Real-time percentage
- Download speed (bytes/sec)
- ETA (time remaining)
- File size (total/downloaded)
- Current file being downloaded

### Error Handling
- Network retry configuration
- Continue on errors (playlists)
- Fragment failure handling
- User feedback on success/failure
- Exit code interpretation

---

## 6. Summary for Implementation

### Download Flow
1. **Input**: User provides URL(s)
2. **Info Fetch**: `yt-dlp -F --dump-json <URL>` to get format list
3. **Format Select**: Present formats to user, or use preset
4. **Config Build**: Construct yt-dlp command with parameters
5. **Execute**: Run yt-dlp with real-time progress capture
6. **Monitor**: Parse stdout/stderr for progress updates
7. **Complete**: Report results and handle errors

### Real-Time Progress Capture
```bash
# Recommended approach
yt-dlp [options] <URL> 2>&1 | tee /tmp/download.log

# Parse progress:
- Track lines: [download] ... (percentage, speed, ETA)
- Parse templates: progress._percent_str, progress._speed_str
- Monitor state: "downloading", "downloaded", "error"
```

### Configuration Flexibility
- Support command-line parameters
- Support config files
- Allow preset aliases (mp3, mp4, mkv)
- Custom output templates
- Per-site overrides

### Error Recovery
- Automatic retry on network errors (configurable)
- Continue on playlist errors (configurable)
- Fragment failure handling
- User-readable error messages
- Exit code interpretation
