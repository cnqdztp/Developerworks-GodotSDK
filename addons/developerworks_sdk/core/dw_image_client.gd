# DWImageClient - Image generation client
# Provides high-level API for AI image generation

extends Node
class_name DWImageClient

var _model: String
var _image_provider: Node

func _init(model: String, image_provider: Node):
	_model = model
	_image_provider = image_provider

## Get model name
func get_model_name() -> String:
	return _model

## Generate a single image
## @param prompt: Text description of the image to generate
## @param size: Image dimensions (e.g., "1024x1024", "1792x1024", "1024x1792")
## @param seed: Optional seed for reproducibility (-1 = random)
## @return: Dictionary with { success: bool, image: GeneratedImage, error: String, error_code: String }
func generate_image_async(
	prompt: String,
	size: String = "1024x1024",
	seed: int = -1
) -> Dictionary:
	if prompt == "":
		var error = DWExceptions.ValidationException.new(
			DWExceptions.MISSING_PARAMETERS,
			"Prompt cannot be empty",
			{"parameter": "prompt"}
		)
		return {
			"success": false,
			"image": null,
			"error": error.message,
			"error_code": error.error_code
		}

	# Validate size before sending request
	var size_validation = _image_provider.validate_size(size)
	if not size_validation.valid:
		var error = size_validation.error
		return {
			"success": false,
			"image": null,
			"error": error.message,
			"error_code": error.error_code
		}

	# Create request
	var request = AIImageDataModels.ImageGenerationRequest.new()
	request.model = _model
	request.prompt = prompt
	request.n = 1
	request.size = size
	request.seed = seed

	# Send request
	var response = await _image_provider.generate_image_async(request)

	if response == null:
		return {
			"success": false,
			"image": null,
			"error": "Failed to generate image. Check logs for details."
		}

	if response.data.size() == 0:
		return {
			"success": false,
			"image": null,
			"error": "No image data in response"
		}

	# Create GeneratedImage from response
	var image_data = response.data[0]
	var generated_image = AIImageDataModels.GeneratedImage.new(
		image_data.b64_json,
		prompt,
		image_data.revised_prompt,
		response.created
	)

	return {
		"success": true,
		"image": generated_image,
		"error": ""
	}

## Generate multiple images
## @param prompt: Text description of the images to generate
## @param count: Number of images to generate (1-10)
## @param size: Image dimensions
## @param aspect_ratio: Alternative to size (e.g., "16:9") - if set, overrides size
## @param seed: Optional seed for reproducibility (-1 = random)
## @return: Dictionary with { success: bool, images: Array[GeneratedImage], error: String, error_code: String }
func generate_images_async(
	prompt: String,
	count: int = 1,
	size: String = "1024x1024",
	aspect_ratio: String = "",
	seed: int = -1
) -> Dictionary:
	if prompt == "":
		var error = DWExceptions.ValidationException.new(
			DWExceptions.MISSING_PARAMETERS,
			"Prompt cannot be empty",
			{"parameter": "prompt"}
		)
		return {
			"success": false,
			"images": [],
			"error": error.message,
			"error_code": error.error_code
		}

	if count < 1 or count > 10:
		var error = DWExceptions.ValidationException.new(
			DWExceptions.VALIDATION_ERROR,
			"Count must be between 1 and 10",
			{"parameter": "count", "provided_value": count, "valid_range": "1-10"}
		)
		return {
			"success": false,
			"images": [],
			"error": error.message,
			"error_code": error.error_code
		}

	# Validate size before sending request
	var size_validation = _image_provider.validate_size(size)
	if not size_validation.valid:
		var error = size_validation.error
		return {
			"success": false,
			"images": [],
			"error": error.message,
			"error_code": error.error_code
		}

	# Create request
	var request = AIImageDataModels.ImageGenerationRequest.new()
	request.model = _model
	request.prompt = prompt
	request.n = count
	request.size = size
	request.aspect_ratio = aspect_ratio
	request.seed = seed

	# Send request
	var response = await _image_provider.generate_image_async(request)

	if response == null:
		return {
			"success": false,
			"images": [],
			"error": "Failed to generate images. Check logs for details."
		}

	if response.data.size() == 0:
		return {
			"success": false,
			"images": [],
			"error": "No image data in response"
		}

	# Create GeneratedImage array from response
	var generated_images = []
	for image_data in response.data:
		var generated_image = AIImageDataModels.GeneratedImage.new(
			image_data.b64_json,
			prompt,
			image_data.revised_prompt,
			response.created
		)
		generated_images.append(generated_image)

	return {
		"success": true,
		"images": generated_images,
		"error": ""
	}

## Static utility: Convert base64 string to Godot Image
## @param base64_data: Base64 encoded image data
## @return: Image object or null on failure
static func base64_to_image(base64_data: String) -> Image:
	if base64_data == "":
		push_error("[DWImageClient] Base64 data is empty")
		return null

	# Decode base64
	var decoded = Marshalls.base64_to_raw(base64_data)
	if decoded.size() == 0:
		push_error("[DWImageClient] Failed to decode base64 data")
		return null

	# Try to load as PNG first
	var image = Image.new()
	var err = image.load_png_from_buffer(decoded)

	# If PNG fails, try JPG
	if err != OK:
		err = image.load_jpg_from_buffer(decoded)

	if err != OK:
		push_error("[DWImageClient] Failed to load image from buffer. Error: ", err)
		return null

	return image

## Static utility: Convert Image to ImageTexture for rendering
## @param image: Godot Image object
## @return: ImageTexture or null on failure
static func image_to_texture(image: Image) -> ImageTexture:
	if image == null:
		push_error("[DWImageClient] Image is null")
		return null

	var texture = ImageTexture.create_from_image(image)
	return texture

## Static utility: Save image to file
## @param image: Godot Image object
## @param file_path: Path to save the image (e.g., "user://my_image.png" or "res://output/image.png")
## @param format: "png" or "jpg" (default: "png")
## @return: true if successful, false otherwise
static func save_image_to_file(image: Image, file_path: String, format: String = "png") -> bool:
	if image == null:
		push_error("[DWImageClient] Image is null")
		return false

	if file_path == "":
		push_error("[DWImageClient] File path is empty")
		return false

	var err = OK
	if format.to_lower() == "jpg" or format.to_lower() == "jpeg":
		err = image.save_jpg(file_path)
	else:
		err = image.save_png(file_path)

	if err != OK:
		push_error("[DWImageClient] Failed to save image to '%s'. Error: %s" % [file_path, err])
		return false

	print("[DWImageClient] Image saved successfully to: ", file_path)
	return true

## Static utility: Save GeneratedImage to file
## @param generated_image: GeneratedImage object
## @param file_path: Path to save the image
## @param format: "png" or "jpg" (default: "png")
## @return: true if successful, false otherwise
static func save_generated_image_to_file(generated_image: AIImageDataModels.GeneratedImage, file_path: String, format: String = "png") -> bool:
	if generated_image == null:
		push_error("[DWImageClient] GeneratedImage is null")
		return false

	var image = generated_image.to_image()
	if image == null:
		return false

	return save_image_to_file(image, file_path, format)