# matrix_color_processor.py
import re
import os

def parse_color_data(line):
    """Parse a line of color coordinates data from test.lua into {x, y, color} format"""
    parts = line.split(',')
    color_points = []
    
    i = 0
    while i < len(parts) - 2:
        try:
            x = int(parts[i])
            y = int(parts[i+1])
            
            # Handle color format (with or without 0x prefix)
            color = parts[i+2]
            if '0x' in color:
                color_hex = color
            else:
                color_hex = f"0x{int(color):06X}"
            
            color_points.append({"x": x, "y": y, "color": color_hex})
            
        except (ValueError, IndexError):
            pass
        
        i += 3
    
    return color_points

def generate_lua_code(patterns):
    """Generate Lua code from the parsed patterns in {x, y, color} format"""
    lua_code = "-- Định nghĩa ma trận màu cho các số 1-50\n"
    lua_code += "local matrix_color_number = {\n"
    
    for i in range(1, 51):
        if i in patterns:
            points = patterns[i]
            lua_code += f"    -- Số {i}\n"
            lua_code += "    {\n"
            
            for point in points:
                lua_code += f"        {{x = {point['x']}, y = {point['y']}, color = {point['color']}}},\n"
            
            lua_code = lua_code.rstrip(",\n") + "\n"
            lua_code += "    }"
            if i < 50:
                lua_code += ","
            lua_code += "\n"
    
    lua_code += "}\n\n"
    lua_code += "return matrix_color_number"
    
    return lua_code

def process_test_lua():
    """Process test.lua file and generate matrix_color_number.lua with {x, y, color} format"""
    patterns = {}
    
    # Read the test.lua file
    with open("lua/test.lua", "r") as file:
        content = file.read()
    
    # Extract patterns for each number
    for i in range(1, 51):
        pattern_match = re.search(rf"{i}\s+:\s+([^\n]+)", content)
        if pattern_match:
            raw_data = pattern_match.group(1)
            patterns[i] = parse_color_data(raw_data)
    
    # Generate Lua code
    lua_code = generate_lua_code(patterns)
    
    # Write to file
    with open("lua/matrix_color_number.lua", "w") as file:
        file.write(lua_code)
    
    print(f"Successfully processed {len(patterns)} color patterns.")
    print("Generated matrix_color_number.lua file with {x, y, color} format.")

if __name__ == "__main__":
    if not os.path.exists("lua"):
        os.makedirs("lua")
    
    if not os.path.exists("lua/test.lua"):
        print("Error: lua/test.lua file not found!")
        exit(1)
    
    process_test_lua()