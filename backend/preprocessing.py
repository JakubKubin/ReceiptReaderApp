#preprocessing.py
import cv2
from cv2.typing import MatLike
import numpy as np
from typing import Optional
from skimage.feature import canny
from skimage.transform import hough_line, hough_line_peaks
from collections import Counter

BLUR_FILER_SIZE = (5,5)
ADAPTIVE_BLOCK_SIZE = 41
ADAPTIVE_WEIGHT = 11

def image_to_gray_scale(image: MatLike) -> MatLike:

    if len(image.shape) == 2:
        return image
    elif len(image.shape) == 3 and image.shape[2] == 3:
        return cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    else:
        raise ValueError("Invalid input: 'image' must be a BGR color image (3 channels) or grayscale image (1 channel).")


def image_to_binary(image: MatLike) -> MatLike:

    if len(image.shape) != 2:
        raise ValueError("Invalid input: 'image' must be a grayscale image (1 channel) for thresholding.")

    try:
        _, binary_image = cv2.threshold(np.uint8(image), 0, 255, cv2.THRESH_BINARY) # type: ignore
        return binary_image
    except Exception as error:
        raise Exception(f"Error making image to binary.\nError: {str(error)}") from error


def blur_image(image: MatLike) -> MatLike:

    if len(image.shape) not in (2, 3):
        raise ValueError("Invalid input: 'image' must be a grayscale (1 channel) or color (3 channels) image.")

    return cv2.GaussianBlur(image, BLUR_FILER_SIZE, 0)


def gaussian_mask(image: MatLike) -> MatLike:

    try:
        return cv2.adaptiveThreshold(cv2.medianBlur(image_to_gray_scale(image),5), 255,
                                     cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, ADAPTIVE_BLOCK_SIZE, ADAPTIVE_WEIGHT)
    except Exception as error:
        raise Exception(f"Error while applying mean threshold mask:\nError: {str(error)}") from error


def mean_mask(image: MatLike) -> MatLike:

    try:
        return cv2.adaptiveThreshold(cv2.medianBlur(image_to_gray_scale(image),5), 255,
                                     cv2.ADAPTIVE_THRESH_MEAN_C, cv2.THRESH_BINARY, 41, 11)
    except Exception as error:
        raise Exception(f"Error while applying mean threshold mask:\nError: {str(error)}") from error


def otsu_mask(image: MatLike) -> MatLike:

    try:
        img_gray = image_to_gray_scale(image)
        blurred = blur_image(img_gray)
        _, thresh = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

        return thresh

    except Exception as error:
        raise Exception(f"Error while applying Otsu's mask:\nError: {str(error)}") from error


def detect_barcode(image: MatLike) -> MatLike:

    try:
        barcode_detector = cv2.barcode.BarcodeDetector()
        found_barcode, points = barcode_detector.detect(image)

        if found_barcode:
            for c in points:
                x, y, w, _ = cv2.boundingRect(c)

                return image[ : y - 30, x-200:x+w+200]

    except Exception as error:
        print(f"Error while detecting barcode: {str(error)}")

    return image


def crop_image(image: MatLike) -> MatLike:

    try:
        gray_image = image_to_gray_scale(image)
        _, thresh = cv2.threshold(cv2.medianBlur(gray_image,5),\
            0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

        contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL,\
            cv2.CHAIN_APPROX_SIMPLE)
        contours = sorted(contours, key=cv2.contourArea, reverse=True) #type: ignore

        for c in contours:
            x, y, w, h = cv2.boundingRect(c)

            return image[int(y + y*0.2) : y + h, x : x + w]

    except Exception as error:
        raise Exception(f"Error while cropping image: {str(error)}") from error

    return image


def add_and_average(first_image: MatLike, second_image: MatLike) -> MatLike:

    try:
        if first_image.shape == second_image.shape:
            return image_to_binary(cv2.add(np.uint8(first_image), np.uint8(second_image)) / 2) #type: ignore

        raise Exception("Images have different shapes")

    except Exception as error:
        raise Exception(f"Error taking average of images:\nError: {str(error)}") from error


def open_binary_image(image: MatLike, erode: tuple[int, int], dilate: tuple[int, int]) -> MatLike:

    try:
        eroded: MatLike = cv2.erode(image, np.ones(erode, np.uint8), iterations=1)
        return cv2.dilate(eroded, np.ones(dilate, np.uint8))
    except Exception as error:
        raise Exception(f"Error opening image:\nError: {str(error)}") from error


def close_binary_image(image: MatLike, erode: tuple[int, int], dilate: tuple[int, int]) -> MatLike:

    try:
        dilated: MatLike = cv2.dilate(image, np.ones(dilate, np.uint8), iterations=1)
        return cv2.erode(dilated, np.ones(erode, np.uint8))
    except Exception as error:
        raise Exception(f"Error opening image:\nError: {str(error)}") from error


def correct_skew(image: MatLike, sigma: float = 1.0, num_peaks: int = 5,
                 min_deviation: float = 0.01, min_angle: Optional[float] = None,
                 max_angle: Optional[float] = None, angle_pm_90: bool = False) -> MatLike:
    """
    Corrects skew in an input image using Hough Transform for line detection.

    Parameters:
        image (MatLike): Input image to correct.
        sigma (float): Standard deviation of the Gaussian filter for Canny edge detection.
        num_peaks (int): Number of peaks to consider in Hough Transform.
        min_deviation (float): Minimum deviation for angle calculation.
        min_angle (float): Minimum angle to filter peaks.
        max_angle (float): Maximum angle to filter peaks.
        angle_pm_90 (bool): Flag to adjust angle within the range of ±90 degrees.

    Returns:
        MatLike: Corrected image, or original image if no skew detected.
    """
    try:
        num_angles = round(np.pi / min_deviation)

        edges = canny(image_to_gray_scale(image), sigma=sigma)

        out, angles, distances = hough_line(edges, np.linspace(-np.pi / 2, np.pi / 2, num_angles, endpoint=False))

        hspace, angles_peaks, dists = hough_line_peaks(out, angles, distances, num_peaks=num_peaks, threshold=0.05 * np.max(out))

        if len(angles_peaks) == 0: #type: ignore
            return image

        freqs_original = {}
        for peak in angles_peaks: #type: ignore
            freqs_original.setdefault(peak, 0)
            freqs_original[peak] += 1

        angles_peaks_corrected = [
            (a % np.pi - np.pi / 2) if angle_pm_90 else ((a + np.pi / 4) % (np.pi / 2) - np.pi / 4)
            for a in angles_peaks #type: ignore
        ]

        angles_peaks_filtered = ([a for a in angles_peaks_corrected if a >= min_angle] if min_angle is not None else angles_peaks_corrected)
        angles_peaks_filtered = ([a for a in angles_peaks_filtered if a <= max_angle] if max_angle is not None else angles_peaks_filtered)

        if not angles_peaks_filtered:
            return image

        freqs = Counter(angles_peaks_filtered)

        max_freq = max(freqs.values())
        max_arr = [peak for peak, freq in freqs.items() if freq == max_freq]

        angle = max_arr[0] if max_arr else max(freqs, key=freqs.get) #type: ignore

        median_angle = np.median(angle * 180 / np.pi)

        (h, w) = image.shape[:2]

        center = (w // 2, h // 2)
        matrix = cv2.getRotationMatrix2D(center, median_angle, 1.0) #type: ignore

        rotated = cv2.warpAffine(image, matrix, (w, h), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_CONSTANT)
        return rotated

    except Exception as error:
        raise Exception(f"Error correcting skew:\nError: {str(error)}") from error


def preprocess(image: MatLike) -> MatLike:

    try:

        cropped_image: MatLike = crop_image(detect_barcode(image))

        gaussian_image: MatLike = open_binary_image(gaussian_mask(cropped_image), (3, 3), (2, 2))

        otsu_image: MatLike = open_binary_image(otsu_mask(cropped_image), (3, 3), (2, 2))

        return correct_skew(open_binary_image(add_and_average(otsu_image, gaussian_image), (2,2), (2,2)))

    except Exception as error:
        raise Exception(f"Error preprocessing image:\nError: {str(error)}") from error