Engine_ShepardOrgan : CroneEngine {

	var voices;
	var n_VOICES = 4;
	var n_HARMONICS = 9;
	var cutoff_low = 30;
	var cutoff_high = 15360; // 30 * 512;

	*new { arg context, callback;
		^super.new(context, callback);
	}

	alloc {

		SynthDef.new(\shepardOrgan, {
			arg out = 0,
				hz = 30,
				glide = 0.1,
				mod_rate = 0.6,
				mod_index = 0.002,
				gate = 0,
				attack = 0.02,
				release = 0.02,
				double_detune = 2,
				octave_detune = 0,
				octave_scale = 2,
				pan = 0;
			var octave = 2 * 2.pow(Lag.kr(octave_detune, glide) / 1200); // detuned octave, really
			var double = 2.pow([double_detune / -2, double_detune / 2] / 1200);
			var bass = Lag.kr(Select.kr(hz / cutoff_low, [hz, hz / octave, hz / octave / octave]), glide);
			// TODO: two freqs per octave, detuned...
			var frequencies = Array.geom(n_HARMONICS, bass, octave).collect({
				arg freq, i;
				freq * SinOsc.kr(mod_rate, iphase: i/2 * pi, mul: mod_index, add: 1) * double;
			}).flat;
			var gains = frequencies.collect({
				arg freq, i;
				(i * -1 * octave_scale).dbamp * freq.explin(cutoff_low, cutoff_low * 4, -60.dbamp, 1) * freq.explin(cutoff_high / 4, cutoff_high, 1, -60.dbamp);
			});
			var specs = `[frequencies, gains];
			var output = DynKlang.ar(specs);
			var env = Env.asr(attack, 1, release);
			OffsetOut.ar(out, Pan2.ar(output, pan, EnvGen.ar(env, gate) * -32.dbamp));
		}).send(context.server);

		context.server.sync;

		voices = Array.fill(n_VOICES, {
			Synth.new(\shepardOrgan);
		});

		[ \hz, \glide, \mod_rate, \mod_index, \gate, \attack, \release, \octave_detune, \double_detune, \octave_scale, \pan ].do({
			arg param;
			// param.postln;
			this.addCommand(param, "if", {
				arg msg;
				var voice = msg[1] - 1;
				// msg.postln;
				voices[voice].set(param, msg[2]);
			});
		});

		/* version used for Disquiet0410:
		SynthDef.new(\shepardOrgan, {
			arg out = 0, hz = 30, glide = 0.1, mod_rate = 0.6, mod_index = 0.002, gate = 0, attack = 0.02, release = 0.02, detune = 0, octave_scale = 2, pan = 0;
			var interval = 2 * 2.pow(Lag.kr(detune, glide) / 1200);
			var bass = Lag.kr(Select.kr(hz / cutoff_low, [hz, hz / interval, hz / interval / interval]), glide);
			var frequencies = Array.geom(n_HARMONICS, bass, interval).collect({
				arg freq, i;
				freq * SinOsc.kr(mod_rate, iphase: i / 2 * pi, mul: mod_index, add: 1); // TODO: FSinOsc won't work here, I guess?
			});
			var gains = frequencies.collect({
				arg freq, i;
				(i * -1 * octave_scale).dbamp * freq.explin(cutoff_low, cutoff_low * 4, -60.dbamp, 1) * freq.explin(cutoff_high / 4, cutoff_high, 1, -60.dbamp);
			});
			var specs = `[frequencies, gains];
			var output = DynKlang.ar(specs);
			var env = Env.asr(attack, 1, release);
			OffsetOut.ar(out, Pan2.ar(output, pan, EnvGen.ar(env, gate) * -32.dbamp));
		}).send(context.server);

		context.server.sync;

		voices = Array.fill(n_VOICES, {
			Synth.new(\shepardOrgan);
		});

		[ \hz, \glide, \mod_rate, \mod_index, \gate, \attack, \release, \detune, \octave_scale, \pan ].do({
			arg param;
			// param.postln;
			this.addCommand(param, "if", {
				arg msg;
				var voice = msg[1] - 1;
				// msg.postln;
				voices[voice].set(param, msg[2]);
			});
		});
		*/
	}

	free {
		voices.do({
			arg synth;
			synth.free;
		});
	}
}
