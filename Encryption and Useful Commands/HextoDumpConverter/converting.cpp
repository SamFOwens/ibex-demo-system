#include <stdio.h>
#include <iostream>
#include <fstream>
#include <string>

using namespace std;

int main() {
    // Open the input dump file (with hex characters)
    std::ifstream input_file("hex.txt");

    // Open the output dump file
    std::ofstream output_file("text-mod.dump");

    char* input = (char*) malloc(4*sizeof(char));
    char* converted = (char*) malloc(8*sizeof(char));

    // Scan the input file 32 bits at a time, and write the string in a format that can be printed to text-mod via terminal
    while (input_file.read (input, 4*sizeof(char))) {
        converted [0] = '\\';
        converted [1] = 'x';
        converted [2] = input[0];
        converted [3] = input[1];
        converted [4] = '\\';
        converted [5] = 'x';
        converted [6] = input[2];
        converted [7] = input[3];
        output_file.write (converted, 8*sizeof(char)); 
    }

    // Close both input and output files
    input_file.close();
    output_file.close();
    free(input);
    free(converted);
    std::cout << "Converted Successfully" << std::endl;

    return 0;
}
