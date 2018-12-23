module bfvm;
import std.stdio;
import std.conv;
import std.string;
import std.algorithm;
import std.array;
import std.range;
import arsd.terminal;

class BFVM
{
	bool silent;
	ubyte[] memory;
	string program;
	string mock_input;
	string output;
	BricketFinder brickets;

	size_t cycle;
	size_t input_ptr;
	size_t memory_ptr;
	size_t instruction_ptr;

	this(size_t memory_size = 4096, bool silent = false)
	{
		this.silent = silent;
		reset();
		setMemorySize(memory_size);
		loadDefault();
	}

	auto toggleSilence()
	{
		silent = !silent;
	}

	auto reset()
	{
		cycle = 0;
		output = "";
		input_ptr = 0;
		memory_ptr = 0;
		mock_input = "";
		instruction_ptr = 0;
		clearMemory();
	}

	auto dumpMemory()
	{
		return memory;
	}

	auto dumpOutput()
	{
		return output;
	}

	auto setMemorySize(size_t size)
	{
		memory.length = size;
	}

	auto load(string program)
	{
		this.program = program;
		brickets = new BricketFinder(program);
	}

	static pure stringToBF(alias str)()
	{
		immutable a = "[-]" ~ reduce!((newProgram, chr) =>	newProgram ~ (join("+".repeat(cast(size_t) chr)) ~ "." ~ join("-".repeat(cast(size_t) chr)))
		)("", str);
		return a;
	}

	auto loadDefault()
	{
		load(stringToBF!("Welcome to your BFVM.\nTo load a program use the .load() method\n")());
	}

	auto clearMemory()
	{
		auto previous_memory_size = memory.length;
		memory.destroy();
		memory.length = previous_memory_size;
	}

	auto encode(string[] array)
	{
		auto encoded_array = reduce!((accumulator, i) => accumulator ~ i.representation ~ [cast(ubyte) 0])(cast(ubyte[])[], array);
		auto encoded_length = cast(ubyte) array.length;
		return [encoded_length] ~ encoded_array;
	}

	auto insertMemory(size_t start, ubyte[] data)
	{
		memory[start..data.length+start] = data;
	}

	auto mockInput(string input)
	{
		input_ptr = 0;
		mock_input = input;
	}

	auto run(size_t max_cycles=0, string[] argv=[])
	{
		insertMemory(0, encode(argv));

		while (instruction_ptr < program.length && (max_cycles == 0 || cycle < max_cycles))
		{
			step();
		}
	}

	auto step()
	{
		switch (program[instruction_ptr])
		{
			case '+':
				memory[memory_ptr]++;
				break;

			case '-':
				memory[memory_ptr]--;
				break;

			case '>':
				if (memory_ptr < memory.length-1)
				{
					memory_ptr++;
				}
				else
				{
					memory_ptr = 0;
				}
				break;

			case '<':
				if (memory_ptr > 0)
				{
					memory_ptr--;
				}
				else
				{
					memory_ptr = memory.length-1;
				}
				break;

			case '.':
				output ~= memory[memory_ptr].to!(char);
				if (!silent)
				{
					write(memory[memory_ptr].to!(char));
				}
				break;

			case ',':
				memory[memory_ptr] = getInput();
				break;

			case '[':
				if (memory[memory_ptr] == 0)
				{
					instruction_ptr = brickets.getCloseBricket(instruction_ptr);
				}
				break;

			case ']':
				instruction_ptr = brickets.getOpenBricket(instruction_ptr);
				return;

			default:
				break;
		}
		instruction_ptr++;
		cycle++;
	}

	auto getInput()
	{
		if (mock_input != "")
		{
			if (input_ptr < mock_input.length)
			{
				auto character = cast(ubyte) mock_input[input_ptr];
				input_ptr++;
				return character;
			}
			else
			{
				return cast(ubyte) 0;
			}
		}
		else
		{
			auto terminal = Terminal(ConsoleOutputType.linear);
			auto terminalInput = RealTimeConsoleInput(&terminal, ConsoleInputFlags.raw);
			return cast(ubyte) terminalInput.getch();
		}
	}
}

class BricketFinder
{
	size_t[size_t] open_bricket_map;
	size_t[size_t] close_bricket_map;

	this(string program)
	{
		size_t[] open_bricket_stack = [];

		size_t instruction_ptr = 0;
		while (instruction_ptr < program.length)
		{
			if (program[instruction_ptr] == '[')
			{
				open_bricket_stack ~= instruction_ptr;
			}
			if (program[instruction_ptr] == ']')
			{
				close_bricket_map[instruction_ptr] = open_bricket_stack.back();
				open_bricket_map[open_bricket_stack.back()] = instruction_ptr;
				open_bricket_stack.popBack();
			}
			instruction_ptr++;
		}
	}

	this(size_t[size_t] open_bricket_map, size_t[size_t] close_bricket_map)
	{
		this.open_bricket_map = open_bricket_map;
		this.close_bricket_map = close_bricket_map;
	}

	auto getOpenBricket(size_t close_bricket_ptr)
	{
		return this.close_bricket_map[close_bricket_ptr];
	}

	auto getCloseBricket(size_t open_bricket_ptr)
	{
		return this.open_bricket_map[open_bricket_ptr];
	}
}

unittest
{
	writeln("Default program");
	auto vm = new BFVM();
	vm.toggleSilence();
	vm.run();
	assert(vm.dumpOutput()=="Welcome to your BFVM.\nTo load a program use the .load() method\n");
}

unittest
{
	writeln("Argument passing");
	auto vm = new BFVM();
	vm.toggleSilence();
	vm.load("[[>]++++++++++++++++++++++++++++++++[<]>-]>[>]<----------------------[<]>[.>]");
	vm.run(0, ["./bfvm","dank memes"]);
	assert(vm.dumpOutput()=="./bfvm dank memes\n");
}

unittest
{
	writeln("Cycle limiting");
	auto vm = new BFVM();
	vm.toggleSilence();
	vm.load("[>.]");
	vm.run(6, ["./bfvm"]);
	assert(vm.dumpOutput()=="./");
}

unittest
{
	writeln("Input mocking");
	auto vm = new BFVM();
	vm.toggleSilence();
	vm.load(",.,.,.");
	vm.mockInput("abc");
	vm.run();
	assert(vm.dumpOutput() == "abc");
}
