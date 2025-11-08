/**
 * Apply transformations to images
 */

const sharp = require('sharp');

/**
 * Apply transformations to image buffer and capture each intermediate step.
 */
async function applyTransformations(imageBuffer, transformations) {
    if (!transformations || transformations.length === 0) {
        return {
            finalBuffer: imageBuffer,
            steps: []
        };
    }

    let currentBuffer = imageBuffer;
    const steps = [];

    for (const transform of transformations) {
        const beforeBuffer = currentBuffer;
        let afterBuffer = beforeBuffer;

        if (transform.Crop) {
            const { x, y, width, height } = transform.Crop;
            console.log(`   ✂️ Applying crop: ${width}x${height} at (${x},${y})`);
            afterBuffer = await sharp(beforeBuffer)
                .extract({
                    left: x,
                    top: y,
                    width: width,
                    height: height
                })
                .toBuffer();

            steps.push({
                type: 'Crop',
                params: { x, y, width, height },
                beforeBuffer,
                afterBuffer
            });
        } else if (transform.Resize) {
            const { width, height } = transform.Resize;
            console.log(`   📐 Applying resize: ${width}x${height}`);
            afterBuffer = await sharp(beforeBuffer)
                .resize(width, height, {
                    fit: 'fill'
                })
                .toBuffer();

            steps.push({
                type: 'Resize',
                params: { width, height },
                beforeBuffer,
                afterBuffer
            });
        } else if (transform.Grayscale) {
            console.log(`   ⚪ Applying grayscale conversion`);
            afterBuffer = await sharp(beforeBuffer)
                .grayscale()
                .toBuffer();

            steps.push({
                type: 'Grayscale',
                params: {},
                beforeBuffer,
                afterBuffer
            });
        } else {
            console.warn(`⚠️  Unknown transformation: ${JSON.stringify(transform)}`);
        }

        currentBuffer = afterBuffer;
    }

    return {
        finalBuffer: currentBuffer,
        steps
    };
}

module.exports = {
    applyTransformations
};


