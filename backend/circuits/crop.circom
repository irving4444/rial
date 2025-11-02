pragma circom "2.0.0";

// This circuit proves that a transformation (e.g., a crop) was applied to an original image
// to produce a transformed image.
//
// Inputs:
// - originalHash: A hash of the original image data (private).
// - transformedHash: A hash of the transformed image data (private).
// - x, y, width, height: The parameters of the transformation (public).
//
// The circuit doesn't perform the actual image processing. Instead, it acts as a template
// to prove that the prover *knew* the private hashes and that they were used in a computation
// along with the public transformation parameters.
template Crop() {
    // Private Inputs
    signal private input originalHash[2]; // Representing a 256-bit hash as 2 x 128-bit numbers
    signal private input transformedHash[2];

    // Public Inputs
    signal input x;
    signal input y;
    signal input width;
    signal input height;

    // Logic to ensure inputs are used
    signal intermediate;
    intermediate <== originalHash[0] + originalHash[1] + transformedHash[0] + transformedHash[1] + x + y + width + height;
    
    signal output out;
    out <== intermediate;
}

component main = Crop();
