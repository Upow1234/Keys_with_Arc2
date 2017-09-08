// two arc led display types: value and LFO

//add back headroom for resonance sweeps

//still have that crazy noise with high resonance high depth LFO low cutoff...

//doesn't load synth def first time

//still uses decay and sustain

//why are strings and arguments same color(purple)?

(
~grid64PortNumber_000 = 18279;
~arc2PortNumber_000 = 18276;

s.makeBundle(s, {
	SynthDef("keys", {arg freq = 50, gate = 1, attack = 1, release = 1, cutoff, resonance, filterLFOspeed = 0.1, filterLFOdepth = 0, detune = 1, fmOverload = 1, masterTune = 1, out = 0, volume = 1;

		var freq1 = (freq * masterTune);
		var freq2 = (freq * masterTune) * (1.001 * detune);
		var freq3 = (freq * masterTune) * (1.003 * detune);
		var freq4 = (freq * masterTune);

		var w2_1 = DynKlang.ar(`[[freq1, freq1 * 3, freq1 * 5, freq1 * 7], [1, 0.19, 0.03, 0.01]]);
		var w4_2 = DynKlang.ar(`[[freq2, freq2 * 2, freq2 * 3, freq2 * 5, freq2 * 7], [1, 0.55, 0.18, 0.03, 0.01]]);
		var w2_3 = DynKlang.ar(`[[freq3, freq3 * 3, freq3 * 5, freq3 * 7], [1, 0.19, 0.03, 0.01]]);
		var w3_4 = DynKlang.ar(`[[freq4, freq4 * 2, freq4 * 4, freq4 * 6, freq4 * 8, freq4 * 10, freq4 * 12], [1, 0.39, 0.08, 0.04, 0.02, 0.01, 0.01]]);

		var levScale = 0.1;

		var env1 = EnvGen.kr(Env([0, 1, 0.75, 0], [0.01 * attack, 0.5 * release, 0.02 * release], releaseNode: 2), gate, (0.9 * levScale), doneAction: 2);
		var env2 = EnvGen.kr(Env([0, 1, 0.75, 0], [0.01 * attack, 0.5 * release, 0.01 * release], releaseNode: 2), gate, (0.8 * levScale));
		var env3 = EnvGen.kr(Env([0, 1, 0.75, 0], [0.01 * attack, 0.5 * release, 0.01 * release], releaseNode: 2), gate, (0.35 * levScale));
		var env4 = EnvGen.kr(Env([0, 1, 0.75, 0], [0.5 * attack, 0.5 * release, 0.011 * release], releaseNode: 2), gate, (0.77 * levScale));

		var output = ((((w2_1  * env1) + (w4_2 * env2)) + (w2_3 * env3)) + (w3_4 * env4));

		Out.ar(out, volume * RLPF.ar(output, Clip.kr(SinOsc.kr(filterLFOspeed, 0, (freq * cutoff) * filterLFOdepth, (freq * cutoff)), 0, 20000), resonance, 0.5));

	}).add;

	SynthDef("Sample Playback", {arg sampleBuffer, volume = 1, cutoff = 20000, resonance = 1,  pitchInversion = 1, pitch = 1;

		var playbuf = PlayBuf.ar(2, sampleBuffer, (pitch * pitchInversion) + 1, loop: 1);

		Out.ar([0, 1], RHPF.ar(RLPF.ar((playbuf * volume), cutoff, resonance), 200));

	}).add;

	SynthDef("Reverb Synth", { arg inputBus, output, roomsize, revtime, damping, inputbw, spread = 15, drylevel, earlylevel,
		taillevel;

		var reverb = GVerb.ar(
			In.ar(inputBus),
			roomsize,
			revtime,
			damping,
			inputbw,
			spread,
			drylevel.dbamp,
			earlylevel.dbamp,
			taillevel.dbamp,
			roomsize, 0.3);

		Out.ar(output, reverb + In.ar(inputBus));

	}).add;

	s.sync;

	s.waitForBoot({

		~grid64_000 = MonoM.new("/monome", 0);
		~arc2_000 = Arc.new("/monome", 0);

		//just sixth is 1.6667
		// 1.6665
		~notes_000 = [ 1, 1.125, 1.25, 1.3333, 1.5, /*set to equal temperment major sixth*/1.667, 1.875, 2];

		//array to hold all playing synths
		~voiceVariables_000 = Array.fill(64, nil);
		~voiceStatus_000 = Array.fill(64, 0);

		~arcSelection_000 = 0;

		//grid led array for left side of grid
		~gridLeds_000 = Array.fill(64, 0);

		~synthsGroup_000 = Group.new;

		~grid64_000.usePort(~grid64PortNumber_000);
		~arc2_000.usePort(~arc2PortNumber_000);

		~sample_000 = Buffer.read(s, "/home/andrew/Music/Solitudes_Vol_6-Side_B.wav");

		~reverbBus_000 = Bus.audio(s, 1);

		//grid functions
		OSCFunc.newMatching(
			{ arg message, time, addr, recvPort;

				var x = message[1];
				var y = message[2];

				var key = (x + (y * 8));
				//the key of the diatonic keyboard: (0 = C), (1 = C#)...
				var root = 7.midicps;
				//used to transpose the scale in ~notes_000 up all octaves
				var octave = [128, 64, 32, 16, 8, 4, 2, 1];
				//faint led array for grid

				//postln(x + "" + y + "" + message[3]);
				if(addr.port == ~grid64PortNumber_000, {
					if (x < 7, {
						switch(message[3], 1, {
							s.makeBundle(nil, {
								//turns playing key led on

								~gridLeds_000[key] = 15;
								~gridLedUpdate_000.value;

								~voiceVariables_000[key] = Synth("keys",
									[\out, ~reverbBus_000,
										\freq, ((~notes_000[x] * root) * octave[y]),
										\attack, ~pairs_000[0][0].currentValue,
										\release, ~pairs_000[0][1].currentValue,
										\cutoff, ~pairs_000[1][0].currentValue,
										\resonance, ~pairs_000[1][1].currentValue,
										\filterLFOspeed, ~pairs_000[2][0].currentValue,
										\filterLFOdepth, ~pairs_000[2][1].currentValue,
										\detune, ~pairs_000[3][0].currentValue,
										\masterTune, ~pairs_000[3][1].currentValue,
										\volume, ~pairs_000[4][0].currentValue
									],
									~synthsGroup_000);

								s.sync;
							});
						}, 0, {
							s.makeBundle(nil, {
								~voiceVariables_000[key].release;

								~gridLeds_000[key] = 4;
								~gridLedUpdate_000.value;
								s.sync;
							});

						});
					}, {
						if(y < ~pairs_000.size, {
							~arcSelection_000 = y;
							postln("~arcSelection_000 = " + y);

							for(0, 7, {arg i;
								~gridLeds_000[x + (i * 8)] = 0;
							});

							~gridLeds_000[x + (y * 8)] = 10;
							~gridLedUpdate_000.value;

							~updateArcLeds_000.value(0, ~pairs_000[~arcSelection_000][0].arcLedValue);
							~updateArcLeds_000.value(1, ~pairs_000[~arcSelection_000][1].arcLedValue);
						});
					});
				});

		}, "/monome/grid/key");

		//function to update grid leds

		~gridLedUpdate_000 = {

			~grid64_000.levmap(0, 0, ~gridLeds_000);

		};


		//initialize grid leds

		for(0, 6, {arg x;
			for(0, 7, {arg y;
				~gridLeds_000[x + (y * 8)] = 4;
			});
		});

		~gridLeds_000[7 + (0 * 8)] = 10;
		~gridLedUpdate_000.value;


		OSCFunc.newMatching(
			{ arg message, time, addr, recvPort;

				var arcFunctions = {arg name, messageOne, messageTwo;
					name.change(messageTwo);
					name.sendChange;
					~updateArcLeds_000.value(messageOne, name.arcLedValue);
				};

				if(addr.port == ~arc2PortNumber_000, {
					switch(message[1], 0, {
						arcFunctions.value(~pairs_000[~arcSelection_000][0], 0, message[2]);
					}, 1, {
						arcFunctions.value(~pairs_000[~arcSelection_000][1], 1, message[2]);
					});
				});

		}, "/monome/enc/delta");

		~samplePlaybackSynth_000 = Synth("Sample Playback", [\sampleBuffer, ~sample_000]);

		~pairs_000 = [
			[ArcParameter.new("Attack", 0.01, 1000, 5, 2, 0.01, ~synthsGroup_000, \attack, 0),
				ArcParameter.new("Release", 0.01, 1000, 5, 2, 0.01, ~synthGroup_000, \release, 0)],
			[ArcParameter.new("Cutoff", 0, 15, 25, 2, 15, ~synthsGroup_000, \cutoff, 0),
				ArcParameter.new("Resonance", 0.1, 1, 100, 2, 1, ~synthsGroup_000, \resonance, 0)],
			[ArcParameter.new("Filter LFO Speed", 0.01, 500, 10, 2, 0.01, ~synthsGroup_000, \filterLFOspeed, 0),
				ArcParameter.new("Filter LFO Depth", 0, 0.95, 100, 2, 0, ~synthsGroup_000, \filterLFOdepth, 0)],
			[ArcParameter.new("Detune", 0.5, 2, 100, 2, 1, ~synthsGroup_000, \detune, 0),
				ArcParameter.new("Master Tune", 0.5, 2, 100, 2, 0.9785, ~synthsGroup_000, \masterTune, 0)],
			[ArcParameter.new("Synth Volume", 0, 1, 100, 2, 0.5, ~synthsGroup_000, \volume, 0),
				ArcParameter.new("Sample Volume", 0, 1, 100, 2, 0, ~samplePlaybackSynth_000, \volume, 0)],
			[ArcParameter.new("Sample Filter Cutoff", 0, 20000, 1, 2, 20000, ~samplePlaybackSynth_000, \cutoff, 0),
				ArcParameter.new("Sample Filter Resonance", 0.1, 1, 100, 2, 1, ~samplePlaybackSynth_000, \resonance, 0)],
			[ArcParameter.new("Pitch Inversion", -1, 1, 0.5, 1, 1, ~samplePlaybackSynth_000, \pitchInversion, 0),
				ArcParameter.new("Sample Pitch", 0, 1, 100, 2, 0, ~samplePlaybackSynth_000, \pitch, 0)]
		];

		for(0, 63, {arg i;
			~voiceVariables_000[i] = Synth.basicNew("keys");
		});

		~samplePlaybackSynth_000.set(\volume, ~pairs_000[4][1].currentValue, \cutoff, ~pairs_000[5][0].currentValue, \resonance, ~pairs_000[5][1].currentValue,  \pitchInversion, ~pairs_000[6][0].currentValue, \pitch, ~pairs_000[6][1].currentValue);

		~updateArcLeds_000 = {arg encoderNumber, ledValue;

			var encoderTemporaryArray = Array.fill(64, { arg index;
				if(index <= ledValue, { 15 }, { 0 });
			});

			~arc2_000.ringmap(encoderNumber, encoderTemporaryArray);

		};

		~updateArcLeds_000.value(0, ~pairs_000[~arcSelection_000][0].arcLedValue);
		~updateArcLeds_000.value(1, ~pairs_000[~arcSelection_000][1].arcLedValue);

		~reverbSynth = Synth.after(~synthGroup_000, "Reverb Synth", [\inputBus, ~reverbBus_000, \output, [0, 1], \roomsize, 80, \revtime, 4.85, \damping, 0.41, \inputbw, 0.19, \drylevel -3, \earlylevel, -9, \taillevel, -11]);

	});

});

)
