#!/usr/bin/env lua

-- Script to generate CAMB initial conditions from COLASolver parameter file
-- Usage: lua get_initial_conditions.lua [parameter_file.lua]

-- Get parameter file from command line argument or use default
local param_file = arg and arg[1] or "parameterfile.lua"

-- Check if parameter file exists
local f = io.open(param_file, "r")
if not f then
	print("Error: Cannot open parameter file: " .. param_file)
	print("Usage: lua " .. arg[0] .. " [parameter_file.lua]")
	os.exit(1)
end
f:close()

-- Load the parameter file
dofile(param_file)

-- Validate required parameters
local required_params = {
	"cosmology_h",
	"cosmology_Omegab",
	"cosmology_OmegaCDM",
	"cosmology_OmegaMNu",
	"cosmology_OmegaK",
	"cosmology_As",
	"cosmology_ns",
	"cosmology_kpivot_mpc",
	"cosmology_TCMB_kelvin",
	"cosmology_Neffective",
	"ic_input_filename",
	"ic_type_of_input",
	"ic_type_of_input_fileformat",
}

for _, param in ipairs(required_params) do
	if not _G[param] then
		print("Error: Missing required parameter: " .. param)
		os.exit(1)
	end
end

if ic_type_of_input_fileformat ~= "CAMB" then
	print("Error: ic_type_of_input_fileformat must be set to CAMB")
	os.exit(1)
end

if ic_type_of_input ~= "powerspectrum" then
	print("Error: ic_type_of_input must be set to powerspectrum")
	os.exit(1)
end

-- Calculate CAMB parameters
local hubble = cosmology_h * 100
local ombh2 = cosmology_Omegab * cosmology_h ^ 2
local omch2 = cosmology_OmegaCDM * cosmology_h ^ 2
local omnuh2 = cosmology_OmegaMNu * cosmology_h ^ 2

-- Extract directory path from ic_input_filename
local input_path = ic_input_filename

-- Find directory part of the path and extract filename
local dir_match = input_path:match("^(.*)/")
print(dir_match)

-- Extract filename without directory for transfer_matterpower
local filename_only = input_path:match("([^/]+)$") or input_path

-- Generate CAMB configuration
local camb_config = string.format(
	[[
#Parameters for CAMB - auto-generated from %s
#See https://github.com/cmbant/CAMB/blob/master/inifiles/params.ini for details

#output_root is prefixed to output file names
output_root = 

#What to do
get_scalar_cls = F
get_vector_cls = F
get_tensor_cls = F
get_transfer   = T

#Non-linear settings
do_nonlinear = 0

#Main cosmological parameters
ombh2          = %.6f
omch2          = %.6f
omnuh2         = %.6f
omk            = %.6f
hubble         = %.1f

#Dark energy model
dark_energy_model  = fluid
w              = -1
cs2_lam        = 1

#CMB and neutrino parameters
temp_cmb           = %.4f
helium_fraction    = 0.24
massless_neutrinos = %.3f

#Neutrino mass settings
nu_mass_eigenstates = 1
massive_neutrinos  = 1
share_delta_neff = T
nu_mass_fractions = 1

#Initial power spectrum
initial_power_num         = 1
pivot_scalar              = %.6f
scalar_amp(1)             = %.6e
scalar_spectral_index(1)  = %.6f
scalar_nrun(1)            = 0

#Reionization
reionization         = T
re_use_optical_depth = T
re_optical_depth     = 0.09
re_delta_redshift    = 1.5
re_ionization_frac   = -1

#Recombination
recombination_model = Recfast

#Initial conditions
initial_condition   = 1

#Normalization
COBE_normalize = F
CMB_outputscale = 7.42835025e12

#Transfer function settings
transfer_high_precision = F
transfer_kmax           = 2
transfer_k_per_logint   = 0
transfer_num_redshifts  = 1
transfer_interp_matterpower = T
transfer_redshift(1)    = 0
transfer_filename(1)    =
transfer_matterpower(1) = %s
transfer_power_var = 7

#Output files
scalar_output_file = 
vector_output_file = 
tensor_output_file = 
total_output_file  = 
lensed_output_file = 
lensed_total_output_file  =
lens_potential_output_file = 

#Accuracy settings
feedback_level = 1
output_file_headers = T
derived_parameters = T
accurate_polarization   = T
accurate_reionization   = F
do_tensor_neutrinos     = T
accurate_massive_neutrino_transfers = F
do_late_rad_truncation   = T
halofit_version = 9
number_of_threads       = 0
accuracy_boost          = 1
l_accuracy_boost        = 1
l_sample_boost          = 1
]],
	param_file,
	ombh2,
	omch2,
	omnuh2,
	cosmology_OmegaK,
	hubble,
	cosmology_TCMB_kelvin,
	cosmology_Neffective,
	cosmology_kpivot_mpc,
	cosmology_As,
	cosmology_ns,
	filename_only
)

print(camb_config)
