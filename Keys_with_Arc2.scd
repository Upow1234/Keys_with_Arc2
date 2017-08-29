// two arc led display types: value and LFO

//control detune amount

//add tuning on the fly

//add back headroom for resonance sweeps

//still have that crazy noise with high resonance high depth LFO low cutoff...


(

//synth
SynthDef("keys", {arg freq = 50, gate = 1, attack = 0.5, decay = 1, sustain = 0.75, release = 1, cutoff, resonance, filterLFOspeed = 0.1, filterLFOdepth = 0;

	var freq1 = freq;
	var freq2 = freq * 1.001;
	var freq3 = freq * 1.003;
	var freq4 = freq;

	var w2_1 = Klang.ar(`[[freq1, freq1 * 3, freq1 * 5, freq1 * 7], [1, 0.19, 0.03, 0.01]]);
	var w4_2 = Klang.ar(`[[freq2, freq2 * 2, freq2 * 3, freq2 * 5, freq2 * 7], [1, 0.55, 0.18, 0.03, 0.01]]);
	var w2_3 = Klang.ar(`[[freq3, freq3 * 3, freq3 * 5, freq3 * 7], [1, 0.19, 0.03, 0.01]]);
	var w3_4 = Klang.ar(`[[freq4, freq4 * 2, freq4 * 4, freq4 * 6, freq4 * 8, freq4 * 10, freq4 * 12], [1, 0.39, 0.08, 0.04, 0.02, 0.01, 0.01]]);

	var levScale = 0.1;

	var env1 = EnvGen.kr(Env([0, 1, 0.5, 0], [0.01 * attack, 0.5, 0.2 * release], releaseNode: 1), gate, (0.9 * levScale), doneAction: 2);
	var env2 = EnvGen.kr(Env([0, 1, 0.5, 0], [0.01 * attack, 0.5, 0.1 * release], releaseNode: 1), gate, (0.8 * levScale));
	var env3 = EnvGen.kr(Env([0, 1, 0.5, 0], [0.01 * attack, 0.5, 0.1 * release], releaseNode: 1), gate, (0.35 * levScale));
	var env4 = EnvGen.kr(Env([0, 1, 0.5, 0], [0.5 * attack, 0.5, 0.11 * release], releaseNode: 1), gate, (0.77 * levScale));

	var output = ((((w2_1  * env1) + (w4_2 * env2)) + (w2_3 * env3)) + (w3_4 * env4));

	//env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: Done.freeSelf);

	Out.ar([0, 1], RLPF.ar(output, SinOsc.kr(filterLFOspeed, 0, (freq * cutoff) * filterLFOdepth, freq * cutoff), resonance, 0.5).softclip);

}).add;

s.waitForBoot({

	//faint led array for right side of grid, second value is led level
	//var faint = Array.fill(64, 2);

	~grid64 = MonoM.new("/monome", 0);
	~arc2 = Arc.new("/monome", 0);

	//just sixth is 1.6667
	//~notes = [ 1, 1.125, 1.25, 1.3333, 1.5, /*set to equal temperment major sixth*/1.68179, 1.875, 2];
	~notes = [ 1, 1.111, 1.25, 1.3333, 1.5, /*set to equal temperment major sixth*/1.6665, 1.875, 2];

	//array to hold all playing synths
	~voiceVariables = Array.fill(64, nil);
	~voiceStatus = Array.fill(64, 0);

	~arcSelection = 0;

	//grid led array for left side of grid
	~gridLeds = Array.fill(64, 0);

	~synthsGroup = Group.new;

	~grid64.usePort(18279);
	~arc2.usePort(18276);


	//grid functions
	OSCFunc.newMatching(
		{ arg message, time, addr, recvPort;

			//index to add synth to ~voiceVariables, message[1] range is moved from
			//8-15 to 0-7 with "- 8"
			var x = message[1];
			var y = message[2];

			var key = (x + (y * 8));
			//the key of the diatonic keyboard: (0 = C), (1 = C#)...
			var root = 7.midicps;
			//used to transpose the scale in ~notes up all octaves
			var octave = [128, 64, 32, 16, 8, 4, 2, 1];
			//faint led array for grid

			//postln(x + "" + y + "" + message[3]);

			if (x < 7, {
				switch(message[3], 1, {
					s.makeBundle(nil, {
						//turns playing key led on

						~gridLeds[key] = 15;
						~gridLedUpdate.value;

						~voiceVariables[key] = Synth("keys", [\freq, ((~notes[x] * root) * octave[y]), \attack, ~pairs[0][0].currentValue, \release, ~pairs[0][1].currentValue, \cutoff, ~pairs[1][0].currentValue, \resonance, ~pairs[1][1].currentValue, \filterLFOspeed, ~pairs[2][0].currentValue, \filterLFOdepth, ~pairs[2][1].currentValue], ~synthsGroup);

						s.sync;
					});
				}, 0, {
					s.makeBundle(nil, {
						~voiceVariables[key].release;

						~gridLeds[key] = 4;
						~gridLedUpdate.value;
						s.sync;
					});

				});
			}, {
				~arcSelection = y;
				postln("~arcSelection = " + y);

				for(0, 7, {arg i;
					~gridLeds[x + (i * 8)] = 0;
				});

				~gridLeds[x + (y * 8)] = 10;
				~gridLedUpdate.value;

				~updateArcLeds.value(0, ~pairs[~arcSelection][0].arcLedValue);
				~updateArcLeds.value(1, ~pairs[~arcSelection][1].arcLedValue);
			});


	}, "/monome/grid/key");

	//function to update grid leds

	~gridLedUpdate = {

		~grid64.levmap(0, 0, ~gridLeds);

	};


	//initialize grid leds

	for(0, 6, {arg x;
		for(0, 7, {arg y;
			~gridLeds[x + (y * 8)] = 4;
		});
	});

	~gridLeds[7 + (0 * 8)] = 10;
	~gridLedUpdate.value;


	OSCFunc.newMatching(
		{ arg message, time, addr, recvPort;

			var arcFunctions = {arg name, messageOne, messageTwo;
				name.change(messageTwo);
				name.sendChange;
				~updateArcLeds.value(messageOne, name.arcLedValue);
			};

			switch(message[1], 0, {
				arcFunctions.value(~pairs[~arcSelection][0], 0, message[2]);
			}, 1, {
				arcFunctions.value(~pairs[~arcSelection][1], 1, message[2]);
			});

	}, "/monome/enc/delta");


	~pairs = [
		[ArcParameter.new("Attack", 0.01, 1000, 1, 2, 0.1, ~synthsGroup, \attack, 0),
			ArcParameter.new("Release", 0.01, 100, 5, 2, 0.1, ~synthGroup, \release, 0)],
		[ArcParameter.new("Cutoff", 0, 15, 25, 2, 15, ~synthsGroup, \cutoff, 0),
			ArcParameter.new("Resonance", 0.1, 1, 50, 2, 1, ~synthsGroup, \resonance, 0)],
		[ArcParameter.new("Filter LFO Speed", 0.01, 500, 10, 2, 0.01, ~synthsGroup, \filterLFOspeed, 0), ArcParameter.new("Filter LFO Depth", 0, 0.95, 100, 2, 0, ~synthsGroup, \filterLFOdepth, 0)]];

	for(0, 63, {arg i;
		~voiceVariables[i] = Synth.basicNew("keys");
	});

	~updateArcLeds = {arg encoderNumber, ledValue;

		var encoderTemporaryArray = Array.fill(64, { arg index;
			if(index <= ledValue, { 15 }, { 0 });
		});

		~arc2.ringmap(encoderNumber, encoderTemporaryArray);

	};

	~updateArcLeds.value(0, ~pairs[~arcSelection][0].arcLedValue);
	~updateArcLeds.value(1, ~pairs[~arcSelection][1].arcLedValue);
});

)

