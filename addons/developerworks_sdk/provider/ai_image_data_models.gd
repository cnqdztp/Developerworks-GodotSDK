# AIImageDataModels - Data models for AI image generation
# Contains request/response structures for image generation API

class_name AIImageDataModels

## ImageGenerationRequest - Request for image generation
class ImageGenerationRequest:
	var model: String = ""
	var prompt: String = ""
	var n: int = 1  # Number of images to generate
	var size: String = "1024x1024"  # Image dimensions
	var aspect_ratio: String = ""  # Alternative to size (e.g., "16:9")
	var seed: int = -1  # For reproducibility (-1 = random)
	var provider_options: Dictionary = {}  # Provider-specific options

	func _init():
		pass

	## Convert to dictionary for API request
	func to_dict() -> Dictionary:
		var data = {
			"model": model,
			"prompt": prompt,
			"n": n,
			"size": size
		}

		# Add aspect ratio if specified
		if aspect_ratio != "":
			data["aspect_ratio"] = aspect_ratio

		# Add seed if specified (not -1)
		if seed != -1:
			data["seed"] = seed

		# Merge provider options
		if not provider_options.is_empty():
			data["provider_options"] = provider_options

		return data

## ImageData - Single image in response
class ImageData:
	var b64_json: String = ""  # Base64 encoded image
	var revised_prompt: String = ""  # AI-revised prompt
	var url: String = ""  # Optional URL (if supported)

	func _init(data: Dictionary = {}):
		if data.has("b64_json"):
			b64_json = data["b64_json"]
		if data.has("revised_prompt"):
			revised_prompt = data["revised_prompt"]
		if data.has("url"):
			url = data["url"]

## ImageGenerationResponse - Response from image generation
class ImageGenerationResponse:
	var created: int = 0  # Unix timestamp
	var data: Array = []  # Array of ImageData

	func _init(response_data: Dictionary = {}):
		if response_data.has("created"):
			created = response_data["created"]

		if response_data.has("data"):
			for item in response_data["data"]:
				data.append(ImageData.new(item))

## GeneratedImage - Public wrapper for generated image with metadata
class GeneratedImage:
	var image_base64: String = ""
	var original_prompt: String = ""
	var revised_prompt: String = ""
	var generated_at: int = 0  # Unix timestamp

	func _init(base64: String = "", orig_prompt: String = "", rev_prompt: String = "", timestamp: int = 0):
		image_base64 = base64
		original_prompt = orig_prompt
		revised_prompt = rev_prompt
		generated_at = timestamp

	## Convert base64 to Godot Image object
	func to_image() -> Image:
		if image_base64 == "":
			push_error("[GeneratedImage] No image data available")
			return null

		# Decode base64
		var decoded = Marshalls.base64_to_raw(image_base64)
		if decoded.size() == 0:
			push_error("[GeneratedImage] Failed to decode base64 image data")
			return null

		# Try to load as PNG first
		var image = Image.new()
		var err = image.load_png_from_buffer(decoded)

		# If PNG fails, try JPG
		if err != OK:
			err = image.load_jpg_from_buffer(decoded)

		if err != OK:
			push_error("[GeneratedImage] Failed to load image from buffer. Error: ", err)
			return null

		return image

	## Convert to Godot ImageTexture
	func to_texture() -> ImageTexture:
		var image = to_image()
		if image == null:
			return null

		var texture = ImageTexture.create_from_image(image)
		return texture