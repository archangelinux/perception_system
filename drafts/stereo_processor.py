import sys
import json
import cv2 as cv
import numpy as np
import base64
import matplotlib
matplotlib.use('Agg')  # Use non-interactive backend
import matplotlib.pyplot as plt
from io import BytesIO

left_path = sys.argv[1]
right_path = sys.argv[2]

imgL = cv.imread(left_path, 0)
imgR = cv.imread(right_path, 0)

stereo = cv.StereoSGBM_create(
    numDisparities=128,  
    blockSize=15      
)

disparity = stereo.compute(imgL, imgR)

disparity_display = cv.normalize(disparity, None, 0, 255, cv.NORM_MINMAX, cv.CV_8U)

fig, axes = plt.subplots(1, 3, figsize=(15, 5))

axes[0].imshow(imgL, 'gray')
axes[0].set_title('Left Image')
axes[0].axis('off')

axes[1].imshow(imgR, 'gray')
axes[1].set_title('Right Image')
axes[1].axis('off')

im = axes[2].imshow(disparity_display, cmap=plt.colormaps.get_cmap('jet'))
axes[2].set_title('Disparity (Depth) Map')
axes[2].axis('off')
plt.colorbar(im, ax=axes[2])

plt.tight_layout()

# Save matplotlib figure to bytes
buffer = BytesIO()
plt.savefig(buffer, format='png', bbox_inches='tight', dpi=100)
buffer.seek(0)
plt.close()

# Convert to base64 for web display

full_figure_base64 = base64.b64encode(buffer.getvalue()).decode('utf-8')

_, buffer_left = cv.imencode('.png', imgL)
left_base64 = base64.b64encode(buffer_left).decode('utf-8')

_, buffer_right = cv.imencode('.png', imgR)
right_base64 = base64.b64encode(buffer_right).decode('utf-8')

fig2, ax = plt.subplots(figsize=(5, 5))
ax.imshow(disparity_display, cmap=plt.colormaps.get_cmap('jet'))
ax.axis('off')
buffer2 = BytesIO()
plt.savefig(buffer2, format='png', bbox_inches='tight', dpi=100)
buffer2.seek(0)
plt.close()
disp_base64 = base64.b64encode(buffer2.getvalue()).decode('utf-8')

valid_mask = disparity > 0

# output JSON for Elixir to read
result = {
    "mean": float(np.mean(disparity[disparity > 0])),
    "max": float(np.max(disparity)),
    "left_image": left_base64,
    "right_image": right_base64,
    "disparity_image": disp_base64,
    "full_figure": full_figure_base64  # The complete matplotlib figure

}
print(json.dumps(result))