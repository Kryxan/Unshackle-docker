#!/bin/bash
set -eux

echo "=== GPU Runtime Check ==="

if grep -qi microsoft /proc/version; then
    echo "WSL2 detected: GPU access depends on Windows drivers and GPU-PV passthrough."
fi

# Check for GPU devices
echo ""
echo "GPU Devices:"
if [ -d /dev/dri ]; then
    ls -la /dev/dri/ 2>/dev/null || echo "/dev/dri exists but is empty"
else
    echo "/dev/dri not found (normal on WSL2/Windows without device passthrough)"
fi

echo ""
echo "Installed GPU Tools:"
command -v vainfo >/dev/null 2>&1 && echo "✓ vainfo (Intel/AMD VA-API)" || echo "✗ vainfo not installed"
command -v nvidia-smi >/dev/null 2>&1 && echo "✓ nvidia-smi (NVIDIA)" || echo "✗ nvidia-smi not installed"
command -v rocminfo >/dev/null 2>&1 && echo "✓ rocminfo (AMD ROCm)" || echo "✗ rocminfo not installed"

# Intel/VA-API check
echo ""
if command -v vainfo >/dev/null 2>&1; then
    echo "Testing VA-API (Intel/AMD):"
    LIBVA_DRIVER_NAME=iHD vainfo 2>&1 | head -15 || echo "VA-API test failed (no device access or driver issue)"
fi

# NVIDIA check
echo ""
if command -v nvidia-smi >/dev/null 2>&1; then
    echo "Testing NVIDIA GPU:"
    nvidia-smi || echo "nvidia-smi failed (likely no NVIDIA GPU mapped)"
fi

# AMD check
echo ""
if command -v rocminfo >/dev/null 2>&1; then
    echo "Testing AMD ROCm:"
    rocminfo | head -20 || echo "rocminfo failed (likely no AMD GPU mapped)"
fi

# FFmpeg hardware encoder capabilities
echo ""
echo "FFmpeg Hardware Encoders Available:"
ffmpeg -hide_banner -encoders 2>&1 | grep -E '(vaapi|qsv|nvenc|amf|v4l2m2m)' | head -10 || echo "No hardware encoders found"

echo ""
echo "=== GPU Runtime Check Complete ==="

