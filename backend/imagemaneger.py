#imagemanager.py
import json
import os

import cv2
from cv2.typing import MatLike
import numpy as np
import pytesseract # type: ignore


SUPPORTED_LANGUAGES = pytesseract.get_languages()
SUPPORTED_IMAGE_EXTENSIONS = [".jpg", ".jpeg", ".png", ".bmp", ".gif"]
COMPRESSION_DELIMITER = "|"


def show_image(image: MatLike) -> None:

    try:
        cv2.namedWindow("Image", cv2.WINDOW_NORMAL)
        cv2.imshow("Image", image)
        cv2.waitKey(0)

    except Exception as error:
        raise Exception(f"Error while displaying the image:\n{str(error)}") from error


def get_image(image_path: str) -> MatLike:

    try:
        if not os.path.exists(image_path):
            raise FileNotFoundError(f"Image file does not exist: {image_path}")

        if not image_path.lower().endswith(tuple(SUPPORTED_IMAGE_EXTENSIONS)):
            raise ValueError(f"Unsupported image format: {image_path}")

        image = cv2.imread(image_path)

        if image is None:
            raise ValueError(f"Failed to load the image: {image_path}")

        return image

    except Exception as error:
        raise ValueError(f"Error while trying to load the image: {str(error)}") from error


def save_image(file_path: str, image: MatLike) -> None:

    try:
        if not file_path:
            raise ValueError("File path is empty.")

        if not cv2.imwrite(file_path, image):
            raise ValueError(f"Failed to save image to: {file_path}")

    except Exception as error:
        raise ValueError(f"Error while trying to save image to: {file_path}\nError: {str(error)}") from error


def image_to_text(image: MatLike, language: str = 'pol') -> str:

    if language not in SUPPORTED_LANGUAGES:
        raise ValueError(f"Unsupported language for OCR: {language}")

    try:
        return pytesseract.image_to_string(image, lang=language)

    except Exception as error:
        raise Exception(f"Error while using Tesseract:\nError: {str(error)}") from error


def image_to_text_file(image: MatLike, language: str, save_path: str, save_filename: str) -> bool:

    try:
        if not os.path.exists(save_path):
            raise FileNotFoundError(f"Save directory does not exist: {save_path}")

        text = image_to_text(image, language)

        with open(f"{os.path.join(save_path,save_filename)}.txt", "w", encoding="utf-8") as f:
            f.write(text)
        print(f"File saved at {os.path.join(save_path,save_filename)}.txt")

        return True

    except Exception as error:
        raise Exception(f"Error while saving image to text file:\n{str(error)}") from error


def compress_binary_string(binary_string: str) -> str:

    try:
        compressed_list = []
        prev_char = None
        count = 0
        for char in binary_string:
            if char == prev_char:
                count += 1
            else:
                if prev_char is not None:
                    compressed_list.append(f"{COMPRESSION_DELIMITER}{count // 2}{prev_char}")
                prev_char = char
                count = 1
        compressed_list.append(f"{COMPRESSION_DELIMITER}{count // 2}{prev_char}" if prev_char else "")
        return "".join(compressed_list)

    except Exception as error:
        raise Exception(f"Error while compressing binary string:\n{str(error)}") from error


def decompress_binary_string(encoded_data: str) -> list[str]:

    try:
        values = encoded_data.split(COMPRESSION_DELIMITER)[1:]
        keys = "".join(v[-1] for v in values)[::-1]
        counts = [int(v[:-1]) for v in values]
        return (
            ("".join(key * count for key, count in zip(keys, counts)))
            .replace("f", "255,")
            .replace("0", "0,")
            .split(",")[:-1]
        )
    except Exception as error:
        raise Exception(f"Error while decompressing binary string:\n{str(error)}") from error


def image_to_json(image: MatLike) -> str:

    try:
        (height, width) = image.shape[:2]
        if height == 0 or width == 0:
            raise ValueError("Invalid image dimensions.")

        compressed_image = compress_binary_string(image.tostring().hex()) #type: ignore

        return json.dumps({"image": compressed_image, "height": height, "width": width})

    except Exception as error:
        raise Exception(f"Error while converting image to JSON:\n{str(error)}") from error


def json_to_image(json_string: str) -> MatLike:

    try:
        if not json_string:
            raise ValueError("JSON string is empty.")

        load = json.loads(json_string)

        if "image" not in load or "height" not in load or "width" not in load:
            raise ValueError("Invalid JSON format for image data.")

        return np.array(np.array(decompress_binary_string(load["image"]), dtype=np.uint8), dtype=np.uint8).reshape((load["height"], load["width"]))
    except Exception as error:
        raise Exception(f"Error while processing JSON data:\n{str(error)}") from error


def save_to_json(file_name: str, image: MatLike) -> None:

    try:
        if not file_name:
            raise ValueError("File name is empty.")

        with open(file_name + ".json", "w") as json_file:
            json.dump(json.loads(str(image_to_json(image))), json_file, ensure_ascii=False)
        print(f"Created JSON file {file_name}.json")

    except Exception as error:
        raise Exception(f"Error while saving image to JSON file:\nError: {str(error)}") from error
