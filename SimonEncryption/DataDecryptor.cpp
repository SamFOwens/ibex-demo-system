#include <stdio.h>
#include <iostream>
#include <fstream>
#include "simon.cpp"

uint64_t simon_64_32_key = 0x1918111009080100UL;

int main() {
    // Open the input dump file in binary write mode
    std::ifstream input_file("encryptedinput.txt");

    // Open the output dump file in binary write mode
    std::ofstream output_file("unencryptedoutput.txt");
    
    // store text data and position
    uint32_t text, ciphertext;

    // Set up for Simon Cipher
    simon_state_t state;
    simon_64_32_keyexpand(&state, simon_64_32_key);

    input_file >> text;
    
    simon_64_32_decrypt(&state, text, &ciphertext);
    
    output_file << ciphertext;

    // Scan the input file by size of text
    /* while (input_file.read (reinterpret_cast<char*>(&text), sizeof(text))) {
        // Convert the endianess to little-endian
        //text = be32toh(text);
        // Encrypt the text 
        text = 41;
        simon_64_32_encrypt(&state, text, &ciphertext);
        // Convert back and write to output file
        //ciphertext = htobe32(ciphertext);
        output_file.write (reinterpret_cast<char*>(&ciphertext), sizeof(ciphertext));
    } */

    // Close both input and output files
    input_file.close();
    output_file.close();

    std::cout << "Ciphertext:" << std::endl;
    std::cout << text << std::endl;
    std::cout << "Text:" << std::endl;
    std::cout << ciphertext << std::endl;
    std::cout << "Decryption completed successfully." << std::endl;

    return 0;
}
