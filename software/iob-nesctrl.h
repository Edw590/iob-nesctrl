#include <stdbool.h>

#include "iob_nesctrl_swreg.h"

//IM functions

//Set IM base address
void nesctrl_init(int base_address);

//Set image memory source

// Get values from inputs
uint16_t nesctrl_get_ctrl1_data();
uint16_t nesctrl_get_ctrl2_data();
