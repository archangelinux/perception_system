import cv2 as cv
import numpy as np
import matplotlib.pyplot as plt

def test_different_parameters():
    #test different stereo matching parameters
    imgL = cv.imread('stereo_kitti_images/aloeL.jpg', 0)
    imgR = cv.imread('stereo_kitti_images/aloeR.jpg', 0)

    figure, axes = plt.subplots(2, 2, figsize=(12, 10))

    settings = [
        (16, 5, "Low disparity, small block/window size"),
        (16, 21, "Low disparity, large block/window size"),
        (96, 5, "High disparity, small block/window size"),
        (96, 21, "High disparity, large block/window size")
    ]

    for i, (num_disp, block_size, description) in enumerate(settings):
        stereo = cv.StereoBM_create(numDisparities = num_disp, blockSize=block_size)
        disparity = stereo.compute(imgL, imgR)
        disparity_display = cv.normalize(disparity, None, 0, 255, cv.NORM_MINMAX, cv.CV_8U)


        #plot
        row = i // 2
        col = i % 2
        axes[row, col].imshow(disparity_display, cmap=plt.cm.get_cmap('Blues', 6))
        axes[row, col].set_title(description)

    plt.tight_layout()
    plt.show()

if __name__ == "__main__":
    test_different_parameters()