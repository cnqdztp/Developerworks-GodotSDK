# Example: AI Image Generation
# Demonstrates how to use the DeveloperWorks SDK for image generation

extends Node

# Reference to image client
var image_client: Node = null

func _ready():
	# Wait for SDK to be initialized (assuming it's initialized in autoload)
	if not DW_SDK.is_ready():
		print("[Example] SDK not ready. Make sure to initialize DW_SDK first.")
		return

	# Create image client (using default model: dall-e-3)
	image_client = DW_SDK.Factory.create_image_client()

	# Run examples
	print("\n========== Image Generation Examples ==========\n")

	# Example 1: Generate single image
	await example_1_basic_generation()

	# Example 2: Generate with seed for reproducibility
	await example_2_with_seed()

	# Example 3: Generate multiple images
	await example_3_multiple_images()

	# Example 4: Save image to file
	await example_4_save_to_file()

	# Example 5: Display image in Sprite2D
	await example_5_display_in_sprite()

	# Example 6: Different image sizes
	await example_6_different_sizes()

	print("\n========== Examples Complete ==========\n")

## Example 1: Generate single image
func example_1_basic_generation():
	print("\n--- Example 1: Basic Image Generation ---")

	var result = await image_client.generate_image_async(
		"A serene mountain landscape at sunset with a lake reflecting the sky"
	)

	if result.success:
		print("Image generated successfully!")
		print("Original prompt: ", result.image.original_prompt)
		print("Revised prompt: ", result.image.revised_prompt)
		print("Generated at: ", result.image.generated_at)

		# Convert to Godot Image
		var godot_image = result.image.to_image()
		if godot_image:
			print("Image size: %dx%d" % [godot_image.get_width(), godot_image.get_height()])
	else:
		print("Failed to generate image: ", result.error)

## Example 2: Generate with seed for reproducibility
func example_2_with_seed():
	print("\n--- Example 2: Image Generation with Seed ---")

	var seed = 42  # Use the same seed to get reproducible results

	var result = await image_client.generate_image_async(
		"A cute robot playing with a puppy",
		"1024x1024",
		seed
	)

	if result.success:
		print("Image generated with seed: ", seed)
		print("Use the same seed to regenerate the same image!")
	else:
		print("Failed: ", result.error)

## Example 3: Generate multiple images
func example_3_multiple_images():
	print("\n--- Example 3: Generate Multiple Images ---")

	var result = await image_client.generate_images_async(
		"Fantasy character portrait, different styles",
		3,  # Generate 3 images
		"1024x1024"
	)

	if result.success:
		print("Generated %d images!" % result.images.size())
		for i in range(result.images.size()):
			var gen_img = result.images[i]
			print("  Image %d: %s" % [i + 1, gen_img.revised_prompt.substr(0, 60) + "..."])
	else:
		print("Failed: ", result.error)

## Example 4: Save image to file
func example_4_save_to_file():
	print("\n--- Example 4: Save Image to File ---")

	var result = await image_client.generate_image_async(
		"A futuristic space station orbiting Earth"
	)

	if result.success:
		var image = result.image.to_image()
		if image:
			# Save to user:// directory (platform-specific user data)
			var saved_png = DWImageClient.save_image_to_file(image, "user://generated_image.png", "png")
			var saved_jpg = DWImageClient.save_image_to_file(image, "user://generated_image.jpg", "jpg")

			if saved_png:
				print("Image saved as PNG: user://generated_image.png")
			if saved_jpg:
				print("Image saved as JPG: user://generated_image.jpg")
	else:
		print("Failed: ", result.error)

## Example 5: Display image in Sprite2D
func example_5_display_in_sprite():
	print("\n--- Example 5: Display in Sprite2D ---")

	var result = await image_client.generate_image_async(
		"A colorful abstract pattern"
	)

	if result.success:
		# Convert to texture
		var texture = result.image.to_texture()
		if texture:
			# Create sprite and add to scene
			var sprite = Sprite2D.new()
			sprite.texture = texture
			sprite.position = Vector2(400, 300)  # Center of screen
			sprite.scale = Vector2(0.5, 0.5)  # Scale down if needed
			add_child(sprite)

			print("Image displayed in Sprite2D!")
			print("Sprite added to scene tree")

			# Optional: Remove after a few seconds
			await get_tree().create_timer(5.0).timeout
			sprite.queue_free()
			print("Sprite removed")
	else:
		print("Failed: ", result.error)

## Example 6: Different image sizes
func example_6_different_sizes():
	print("\n--- Example 6: Different Image Sizes ---")

	# Square image
	var result_square = await image_client.generate_image_async(
		"A symmetrical mandala pattern",
		"1024x1024"
	)

	if result_square.success:
		print("Square image (1024x1024) generated!")

	# Landscape image
	var result_landscape = await image_client.generate_image_async(
		"A wide panoramic view of a cityscape",
		"1792x1024"
	)

	if result_landscape.success:
		print("Landscape image (1792x1024) generated!")

	# Portrait image
	var result_portrait = await image_client.generate_image_async(
		"A tall tower reaching into the clouds",
		"1024x1792"
	)

	if result_portrait.success:
		print("Portrait image (1024x1792) generated!")

## Example 7: Advanced - Generate and process
func example_7_advanced():
	print("\n--- Example 7: Advanced Usage ---")

	# Generate image
	var result = await image_client.generate_images_async(
		"Game asset: fantasy sword icons",
		2,
		"1024x1024",
		"",  # No aspect ratio
		123  # Seed for consistency
	)

	if result.success:
		for i in range(result.images.size()):
			var gen_img = result.images[i]
			var image = gen_img.to_image()

			# Process image (example: resize)
			image.resize(512, 512)

			# Save with custom name
			var filename = "user://sword_icon_%d.png" % i
			DWImageClient.save_image_to_file(image, filename)
			print("Saved: ", filename)
	else:
		print("Failed: ", result.error)

## Utility: Generate and get base64
func utility_get_base64():
	var result = await image_client.generate_image_async("A simple icon")

	if result.success:
		var base64 = result.image.image_base64
		print("Base64 data length: ", base64.length())
		# You can store this in a database or send over network
		return base64

	return ""