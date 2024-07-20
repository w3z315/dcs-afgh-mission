import os
from datetime import datetime

# Define the working directory (one level up from the current script's directory)
working_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "../scripts"))

# Define the output file
output_file = os.path.join(os.path.abspath(os.path.join(working_dir, "../build")), '_mission.lua')

# Delete the output file if it exists
if os.path.exists(output_file):
    os.remove(output_file)

# Function to append the contents of a file to the output file
def append_file_contents(file_path, output_file_handle):
    with open(file_path, 'r') as file_handle:
        output_file_handle.write(f"-- Start of {os.path.basename(file_path)} --\n")
        output_file_handle.write(file_handle.read())
        output_file_handle.write(f"\n-- End of {os.path.basename(file_path)} --\n\n")

# Function to get all .lua files recursively and sort them alphabetically
def get_all_lua_files(directory):
    lua_files = []
    for root, _, files in os.walk(directory):
        for file in sorted(files):
            if file.endswith('.lua'):
                lua_files.append(os.path.relpath(os.path.join(root, file), working_dir))
    return sorted(lua_files)

# Get the current date and time
build_datetime = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

# Get all .lua files in the working directory and its subdirectories, sorted alphabetically
lua_files = get_all_lua_files(working_dir)

# Open the output file in write mode
with open(output_file, 'w') as output_file_handle:
    # Write build information at the beginning of the file
    output_file_handle.write(f"-- Build Date and Time: {build_datetime} --\n\n")

    # Append the contents of each .lua file to the output file
    for relative_path in lua_files:
        file_path = os.path.join(working_dir, relative_path)
        append_file_contents(file_path, output_file_handle)

print(f"All Lua files have been concatenated into {output_file}")
