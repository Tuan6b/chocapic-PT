# Enhanced Global Illumination for Chocapic13 V9 Extreme Shaders

This shader pack has been updated with an enhanced Screen Space Global Illumination (SSGI) system that provides more realistic lighting in your Minecraft world.

## What is Global Illumination?

Global Illumination is a lighting technique that simulates how light bounces from surfaces to other surfaces in the scene. This creates more realistic and dynamic lighting, with effects like:

- Color bleeding (colors from one surface affecting nearby surfaces)
- Indirect lighting (light bouncing around corners)
- Soft ambient lighting that varies based on the environment

## New Features

The enhanced GI system includes several new settings in the shader options:

### Main Controls
- `SSGI`: Enable/disable global illumination (0 = off, 1 = on)
- `ADVANCED_GI`: Toggle between standard and enhanced GI algorithms (0 = standard, 1 = enhanced)
- `GI_STRENGTH`: Controls the overall strength of the global illumination effect (0.1 - 2.0)

### Quality Settings
- `GI_QUALITY`: Adjusts the quality vs. performance ratio (0.1 - 1.0)
- `RAY_COUNT`: Number of rays used for GI calculations (more rays = better quality but lower performance)
- `STEPS`: Number of steps per ray (higher values detect more detail but cost performance)
- `STEP_LENGTH`: Length of each ray step (affects how far light can travel)

### Advanced Settings
- `COLOR_BLEEDING`: Controls how much color from surfaces affects bounced light (0.0 - 1.5)
- `SKY_CONTRIBUTION`: Controls how much sky light contributes to global illumination (0.0 - 0.5)

## Performance Considerations

Global Illumination is computationally expensive. To optimize performance:

1. Reduce `RAY_COUNT` for better performance at the cost of quality
2. Lower `GI_QUALITY` for a significant performance boost with some visual degradation
3. If you experience low FPS, try disabling `ADVANCED_GI` to use the simpler GI algorithm
4. For very low-end systems, set `SSGI` to 0 to disable global illumination entirely

## Recommended Settings

### High-End Systems
- `SSGI`: 1
- `ADVANCED_GI`: 1
- `GI_STRENGTH`: 1.0 - 1.5
- `GI_QUALITY`: 0.8 - 1.0
- `RAY_COUNT`: 6 - 16
- `STEPS`: 12 - 24

### Mid-Range Systems
- `SSGI`: 1
- `ADVANCED_GI`: 1
- `GI_STRENGTH`: 0.8 - 1.2
- `GI_QUALITY`: 0.5 - 0.7
- `RAY_COUNT`: 4 - 8
- `STEPS`: 8 - 12

### Low-End Systems
- `SSGI`: 1
- `ADVANCED_GI`: 0
- `GI_STRENGTH`: 0.5 - 1.0
- `GI_QUALITY`: 0.3 - 0.5
- `RAY_COUNT`: 1 - 4
- `STEPS`: 6 - 8

Enjoy the enhanced lighting in your Minecraft world! 