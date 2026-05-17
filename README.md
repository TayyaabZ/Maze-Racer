# 🕹️ Maze Racer (x86 Assembly)

**Maze Racer** is a fully playable, first-person 3D maze game built entirely from scratch in 16-bit x86 Assembly Language. It was developed as a Complex Engineering Problem (CEP) for the Computer Organization and Assembly Language (COAL) course at Bahria University. 

Instead of building a simple utility program, this project demonstrates core low-level computing concepts—such as memory-mapped I/O, hardware interrupts, stack manipulation, and bitwise arithmetic—through a real-time, playable 3D game engine.

## 🌟 Key Features

* **3D Raycasting Engine:** Renders a first-person perspective in VGA Mode 13h using a custom Digital Differential Analyzer (DDA) algorithm with distance-based shading.
* **Tear-Free Double Buffering:** Utilizes an off-screen memory segment to draw the full 64KB frame before blitting it to the VGA buffer during the VSYNC interval, completely eliminating screen tearing.
* **Procedural Maze Generation:** Generates a unique, solvable "Braid Maze" on every run using a Recursive Backtracker algorithm with a manual memory stack, followed by a braiding pass to knock down internal walls and create flanking routes.
* **Dual-Agent AI Pathfinding:** Features two distinct enemies running simultaneously:
  * *The Smart Wanderer:* Uses memory registers to explore intersections without backtracking.
  * *The Hunter:* Executes a Right-Hand Rule wall-following algorithm to systematically trace and map the maze.
* **Hardware-Level Proximity Audio:** Directly manipulates the Programmable Interval Timer (PIT) and PC Speaker (Ports 42h, 43h, 61h) to create a dynamic "Geiger counter" heartbeat that scales in pitch as enemies get closer.
* **Asynchronous Input & Timing:** Hijacks the system timer (`INT 1Ch`) to decouple AI movement from the 3D rendering framerate, and uses non-blocking keyboard polling (`INT 16h`) for fluid movement controls.
* **Custom Vector Font Engine:** Features a dynamic, scalable UI text renderer drawn directly into the pixel buffer using bitwise shift operations.

## 🎮 Gameplay & Controls

You are dropped into a procedurally generated maze. Find the exit (indicated by the green marker on the minimap) before the timer runs out, and do not let the red enemies catch you.

* **W** - Move Forward
* **S** - Move Backward
* **A** - Turn Left
* **D** - Turn Right
* **ESC** - Quit Game

## 💀 Difficulty Modes

* **Easy:** 9x9 Map. Generous timer (3600 ticks). No enemies. Full minimap.
* **Normal:** 15x15 Map. Standard timer (2160 ticks). Two active enemies visible on the minimap.
* **Hard (Nightmare):** 15x15 Map. Oppressive pitch-black sky and floor with bright orange walls. Enemies are invisible on the minimap. Features a "Fog of War" minimap (only shows tiles you have physically stepped on) and a directional red-strobe threat indicator tied to the PC speaker heartbeat.

## 🛠️ Technical Architecture

* **Language:** x86 Assembly (16-bit)
* **Assembler/Emulator:** Compiled with **NASM** (Netwide Assembler) / Run via **DOSBox-X**
* **Graphics:** VGA Mode 13h (320x200, 256 Colors)
* **Memory Management:** Extensive use of the Data Segment (`DS`) for state flags/maps and Extra Segment (`ES`) for the off-screen video buffer.

## 🚀 How to Run

1. Clone this repository.
2. Ensure you have NASM installed. Compile the source code to a `.COM` executable:
   `nasm -f bin maze.asm -o maze.com`
3. Launch DOSBox or DOSBox-X.
4. Mount the directory containing `maze.com` and run the executable:
   `maze.com`
   *(Note: For the best performance and fluid 3D rendering, adjusting the DOSBox cycles may be required depending on your host machine).*

## 👥 Developers

* **Anood Tayyeba Imtiaz** (01-135232-010) - `screens.asm` state logic, 2D Minimap rendering (including Fog-of-War), UI/Font rendering subsystem, PC speaker audio, and timer rendering. 
* **Muhammad Tayyaab Zahoor** (01-135232-070) - 3D DDA Raycaster engine, procedural maze generation (Backtracker & Braid loops), Dual-Agent AI pathfinding, hardware timer interrupts (`INT 1Ch`), and bitmask collision detection.
