extends RefCounted
## Original synthesized cues; independent of the combat soundtrack and clock.
static func make(kind: int) -> AudioStreamWAV:
	var duration: float = [0.12, 0.65, 0.10][kind]
	var rate := 22050
	var count := int(duration * rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var phase := 0.0
	for i in range(count):
		var t := float(i) / rate
		var u := t / duration
		var frequency: float = [880.0 * pow(0.35, u), 220.0 + 660.0 * u * u, 1046.5][kind]
		phase += TAU * frequency / rate
		var sine := sin(phase)
		var wave := sine * 0.7 + signf(sine) * 0.3
		var envelope := minf(t / 0.004, 1.0) * pow(1.0 - u, 2 if kind != 1 else 0.5)
		bytes.encode_s16(i * 2, int(wave * envelope * 16000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	return stream
