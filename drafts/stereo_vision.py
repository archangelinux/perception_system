#goal: use K matrices and distortion coeffecients for 2 cameras, as well as rotation and translation between cameras
#use triangulation to find disparity (distance from left to right camera) which tells us the depth

import cv2 as cv
import numpy as np
import matplotlib.pyplot as plt

# from: http://www.cvlibs.net/datasets/kitti/raw_data.php


# load a stereo pair (download from KITTI or take two photos)
imgL = cv.imread('stereo_kitti_images/aloeL.jpg', 0)  # grayscale
imgR = cv.imread('stereo_kitti_images/aloeR.jpg', 0)

# create stereo matcher; StereoBM uses sum of absolute differences
stereo = cv.StereoSGBM_create(numDisparities=128, blockSize=15) #semi-global block matching better quality thatn block matching
# numDisparities: sets number of pixels to search for matches (div by 16, 64 is a med range); larger values can detect very close objects but with slower computation
# blockSize: this is the window size for matching - smaller has better locality (more fine features) but has more noise, larger has less noise but worse locality (could be blurrier)

# approach - adaptive window/block size: for each point match using windows of multiple sizes, and use disparity that is a result of the best similarity measure (SSD)

# compute disparity (shift between images)
disparity = stereo.compute(imgL, imgR)

#normalize for display
disparity_display = cv.normalize(disparity, None, 0, 255, cv.NORM_MINMAX, cv.CV_8U)

# visualize depth map
fig, axes = plt.subplots(1, 3, figsize=(15, 5))
axes[0].imshow(imgL, 'gray')
axes[0].set_title('Left Image')
    
axes[1].imshow(imgR, 'gray')
axes[1].set_title('Right Image')
    
plt.colorbar(axes[2].imshow(disparity_display, cmap=plt.cm.get_cmap('Blues', 10)), ax=axes[2])
axes[2].set_title('Disparity (Depth) Map')

plt.tight_layout()
plt.show()

#closer objects have more disparity (shift more between views)
#disparity = ul - ur is the difference in the image location of the same 3D point when projected onyo left and right image planes
# is inversely proportional to depth, and proportional to baseline, the distance between the two cameras