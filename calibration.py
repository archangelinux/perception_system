#goal: to find 1) intrinsic camera matrix K and 2) distortion coefficients

import cv2 as cv
import numpy as np
import glob #for file pattern matching
import os
import matplotlib.pyplot as plt

# termination criteria for OpenCVs optimiztaion algorithm
# when to stop refining corner detection (for cornerSubPix)
# either 30 iterations or accuracy of 0.001 pixels, whichever comes first
criteria = (cv.TERM_CRITERIA_EPS + cv.TERM_CRITERIA_MAX_ITER, 30, 0.001)

# number of inner corner (cols, rows)
BOARD_SIZE = (7, 6)
X_SPACING = 1  #set to 1 unit
Y_SPACING = 1  

# create 3D coordinates (object points) for each corner (assume 1 unit apart)
objp = np.zeros((BOARD_SIZE[0] * BOARD_SIZE[1], 3), np.float32) #total number of corners * 3 (X,Y,Z) coordinate array, initially all (0, 0, 0)
objp[: , :2] = np.mgrid[0:BOARD_SIZE[0],0:BOARD_SIZE[1]].T.reshape(-1,2) # 2 mesh grids, X from 0 to num cols, Y from 0 to num rows
objp[:, 0] *= X_SPACING 
objp[:, 1] *= Y_SPACING
# .T transposes (flips rows & cols) 2 grids each 6*7 becomes 7*6 pixels, each containing 2 dimensions
#.reshape(-1, 2) means make the second dimension 2, and figure out the first dimension automatically
# set all rows, and first 2 columns, leave the third column for Z = 0
# overall: shape (grid, row, col) : (2, 6, 7) --> (7, 6, 2) --> (42, 2), same thing as looping through ranges and appending (x, y, 0) 
print(f"First few 3D points we defined:\n{objp[:3]}")
print(f"Total points: {len(objp)}")

objpoints = [] # 3D points in real world space; will hold the same 3D points for each image. We currently have them 1 unit apart
imgpoints = [] # 2D points in image plane; will have different pixel locations for each image
 
images = glob.glob('calibration_images/left*.jpg')

# process each image
for fname in images:
    img = cv.imread(fname)
    gray = cv.cvtColor(img, cv.COLOR_BGR2GRAY) #grayscale - corner detection works on intensity gradients
 
    # find 2D corner locations (image points)
    ret, corners = cv.findChessboardCorners(gray, BOARD_SIZE, None) #uses gradient analysis and pattern matching
    #ret - True/False: if all corners were found
    #corners - array of 2D points where corners appear in the image (left to right, top to bottom)

    #if corners found, add object points, image points (after refining them)
    if ret == True:
        objpoints.append(objp) #same 3D points for each image
        #sub-pixel refinement for better accuracy
        corners2 = cv.cornerSubPix(gray, corners, (11,11), (-1,-1), criteria) #take initial corner locations, search an 11x11 window size, with no dead zone
        imgpoints.append(corners2) #store the refined 2D points
 
        # visualization
        cv.drawChessboardCorners(img, (7,6), corners2, ret)
        cv.imshow('img', img)
        cv.waitKey(1000) #display time
cv.destroyAllWindows() #kill visualization display

#we have the data for calibration in objpoints and imgpoints
#calibrateCamera solves for intrinsic matrix K and dist, as well as rotation matrix R and translation vector t
ret, K, dist, rMatr, tVec = cv.calibrateCamera(
    objpoints, imgpoints, gray.shape[::-1], None, None
)

#save multiple arrays into a single compressed file (numpy zip file)
np.savez('calibration_data.npz', K = K, dist = dist, image_size = gray.shape[::-1]) #reverse (height, width) --> (width, height) for numpy

# Formula: x = PX where P = K[R|t]

# X = [X,Y,Z,1] is a 3D point in world (homogeneous coords)
# x = [u,v,1] is 2D point in image (homogeneous coords)
# P is 3x4 projection matrix
# K is 3x3 intrinsic matrix (focal length, principal point)
# [R|t] is 3x4 extrinsic matrix (rotation R, translation t)

# K matrix:
# [[fx,  0, cx],
#  [ 0, fy, cy],
#  [ 0,  0,  1]]
# fx, fy = focal length in pixels
# cx, cy = principal point (image center)
# s = (0,1) = 0 is the skew

# dist contains: [k1, k2, p1, p2, k3]
# k1,k2,k3 = radial distortion (barrel/pincushion/mustache)
# p1,p2 = tangential distortion (lens not parallel)


## the fundamental equation (in homogeneous coordinates):
#[u]   [fx  0  cx] [r11 r12 r13 t1] [X]
#[v] = [ 0 fy  cy] [r21 r22 r23 t2] [Y]
#[1]   [ 0  0   1] [r31 r32 r33 t3] [Z]

# For corner i in image j:
#u_ij = (fx * (r11*X_i + r12*Y_i + r13*Z_i + t1) / denominator) + cx
#v_ij = (fy * (r21*X_i + r22*Y_i + r23*Z_i + t2) / denominator) + cy

print("\nCAMERA MATRIX K:")
print(K)
print(f"\nFocal length: fx={K[0,0]:.1f}, fy={K[1,1]:.1f} pixels")
print(f"Principal point: cx={K[0,2]:.1f}, cy={K[1,2]:.1f}")

print("\nDISTORTION COEFFICIENTS:")
print(dist)



#load a test image
test_image_path = images[0]
test_img = cv.imread(test_image_path) #read from disk into numpy array, returns BGR format, (height, width, 3) for colour image (3 channels)
height, width = test_img.shape[:2]

#get optimal matrix
#adjusts the camera matrix for undistortion (can choose to keep all pixels or crop)
#alpha = 1 means to keep all pixels (=0 means to crop all invalid pixels, but might lose corners, =0.5 balances between the two)
new_K, reg_of_interest = cv.getOptimalNewCameraMatrix(K, dist, (width, height), 1, (width, height)) #new image size same as original
#region of interest (ROI) is a tuple (x, y, width, height) of valid image area


#undistort - for each pixel in the output image, calculate where it came from in the distorted image and copy that pixel value
undistorted = cv.undistort(test_img, K, dist, None, new_K) #None for optional rectification transformation (used for stereo)

#crop to ROI
x, y, roi_w, roi_h = reg_of_interest #unpack the tuple
if roi_w > 0 and roi_h > 0:
    undist_cropped = undistorted[y:y+roi_h, x:x+roi_w]
else:
    undist_cropped = undistorted

#visualization - creates multiple subplots (1x3 grid) numrows, numcols, and size in inches
figure, axes = plt.subplots(1, 3, figsize = (12, 4))
#axes is array of subpot axes [ax1, ax2, ax3]

axes[0].imshow(cv.cvtColor(img, cv.COLOR_BGR2RGB))
axes[0].set_title('Original (Distorted)')
axes[0].grid(True, alpha=0.3)

axes[1].imshow(cv.cvtColor(undistorted, cv.COLOR_BGR2RGB))
axes[1].set_title('Undistorted (Full)')
axes[1].grid(True, alpha=0.3)

axes[2].imshow(cv.cvtColor(undist_cropped, cv.COLOR_BGR2RGB))
axes[2].set_title('Undistorted (Cropped)')
axes[2].grid(True, alpha=0.3)

plt.tight_layout()  # adjust spacing
plt.show() 


#save image to disk
output_dir = 'undistorted_images'
os.makedirs(output_dir, exist_ok=True)
output_path = os.path.join(output_dir, 'undist_' + os.path.basename(test_image_path))
cv.imwrite(output_path, undist_cropped)


#calculate reprojection error - how good is the calibration
mean_error = 0
for i in range(len(objpoints)): #for each image
    #where corners should appear based on calibration
    imgpointsCal, _ =  cv.projectPoints(objpoints[i], rMatr[i], tVec[i], K, dist)
    error = cv.norm(imgpoints[i], imgpointsCal, cv.NORM_L2) / len(imgpointsCal) #get average error per point
    mean_error += error 

mean_error = mean_error / len(objpoints)  # Average across all images
print(f"\nAverage reprojection error: {mean_error:.3f} pixels")
print("(Lower is better - under 1.0 pixel is good)")

#load saved calibration
#data = np.load('calibration_data.npz')
#K = data['K']
#dist = data['dist']