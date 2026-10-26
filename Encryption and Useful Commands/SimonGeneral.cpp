#include <stdio.h>
#include <iostream>
#include <fstream>
#include "simon.cpp"

uint64_t simon_64_32_key = 0x1918111009080100UL;

int main() {

    // store text data and position
    uint32_t input, output;
    bool isEnc, isDec;
	
    // Prompt whether to enc/dec, and whether input is dec/hex
    std::cout << "Enter whether to encrypt or decrypt, 1 is encrypt, 0 is decrypt:";
    std::cin >> isEnc;
    
    std::cout << "Enter whether to enter data as decimal or hex, 1 is decimal, 0 is hex:";
    std::cin >> isDec;
    
    std::cout << "Enter the value to be decrypted:";
    if (isDec) {
    	std::cin >> std::dec >> input;
    } else {
    	std::cin >> std::hex >> input;
    }
    
    // Set up for Simon Cipher
    simon_state_t state;
    simon_64_32_keyexpand(&state, simon_64_32_key);
    
    if (isEnc) {
    	simon_64_32_encrypt(&state, input, &output);
    } else {
    	simon_64_32_decrypt(&state, input, &output);
    }
	
    if (isEnc) {
    	std::cout << std::endl << "Hex Outputs:" << std::endl;	
    	std::cout << "Text:" << std::endl;
    	std::cout << std::hex << input << std::endl;
    	std::cout << "Ciphertext:" << std::endl;
    	std::cout << std::hex << output << std::endl;
    	
    	std::cout << std::endl << "Dec Outputs:" << std::endl;	
    	std::cout << "Text:" << std::endl;
    	std::cout << std::dec << input << std::endl;
    	std::cout << "Ciphertext:" << std::endl;
    	std::cout << std::dec << output << std::endl;
    	
    } else {
    	std::cout << std::endl << "Hex Outputs:" << std::endl;	
    	std::cout << "Ciphertext:" << std::endl;
    	std::cout << std::hex << input << std::endl;
    	std::cout << "Text:" << std::endl;
    	std::cout << std::hex << output << std::endl;
    	
    	std::cout << std::endl << "Dec Outputs:" << std::endl;	
    	std::cout << "Ciphertext:" << std::endl;
    	std::cout << std::dec << input << std::endl;
    	std::cout << "Text:" << std::endl;
    	std::cout << std::dec << output << std::endl;
    } 

    std::cout << "Operation completed successfully." << std::endl;

    return 0;
}
