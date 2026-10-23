import SwiftUI
import AVFoundation
import AVKit

/// AirPlay picker: on iOS 26.4+ with CarPlay connected, the car display shows up here.
struct RoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let v = AVRoutePickerView()
        v.prioritizesVideoDevices = true
        v.tintColor = .white
        v.activeTintColor = .systemGreen
        return v
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

final class PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let v = PlayerUIView()
        v.playerLayer.player = player
        v.playerLayer.videoGravity = .resizeAspect
        v.backgroundColor = .black
        return v
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {}
}

struct PlayerView: View {
    @ObservedObject private var model = PlayerModel.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showControls = true
    @State private var scrubbing = false
    @State private var scrubValue: Double = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            PlayerLayerView(player: model.player)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) { showControls.toggle() }
                }
            VStack {
                Spacer()
                if !model.subtitle.isEmpty {
                    Text(model.subtitle)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.55))
                        .cornerRadius(8)
                        .padding(.bottom, showControls ? 150 : 30)
                }
            }
            .padding(.horizontal, 20)
            .allowsHitTesting(false)
            if showControls {
                controls
                    .transition(.opacity)
            }
        }
        .statusBarHidden(!showControls)
    }

    private var controls: some View {
        VStack {
            HStack(spacing: 16) {
                Button {
                    model.stop()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.down.circle.fill").font(.system(size: 40))
                }
                Spacer()
                Text(model.current?.title ?? "")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                RoutePicker().frame(width: 44, height: 44)
                Menu {
                    ForEach(PlayerModel.rates, id: \.self) { r in
                        Button { model.setRate(r) } label: { Text(String(format: "%gx", r)) }
                    }
                } label: {
                    Text(String(format: "%gx", model.rate))
                        .font(.title3.bold())
                        .frame(width: 70, height: 44)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            Spacer()

            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Text(fmt(scrubbing ? scrubValue : model.currentTime))
                    Slider(
                        value: Binding(
                            get: { scrubbing ? scrubValue : model.currentTime },
                            set: { scrubValue = $0 }
                        ),
                        in: 0...max(model.duration, 1),
                        onEditingChanged: { editing in
                            if editing {
                                scrubbing = true
                            } else {
                                model.seek(to: scrubValue)
                                scrubbing = false
                            }
                        }
                    )
                    Text(fmt(model.duration))
                }
                .font(.caption.monospacedDigit())

                HStack(spacing: 40) {
                    bigButton("backward.end.fill", 30) { model.previous() }
                    bigButton("gobackward.10", 34) { model.seek(by: -10) }
                    bigButton(model.isPlaying ? "pause.circle.fill" : "play.circle.fill", 64) { model.toggle() }
                    bigButton("goforward.10", 34) { model.seek(by: 10) }
                    bigButton("forward.end.fill", 30) { model.next() }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .foregroundColor(.white)
        .background(
            LinearGradient(colors: [Color.black.opacity(0.6), Color.clear, Color.clear, Color.black.opacity(0.75)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        )
    }

    private func bigButton(_ name: String, _ size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: size))
                .frame(width: max(size * 1.4, 56), height: max(size * 1.4, 56))
                .contentShape(Rectangle())
        }
    }

    private func fmt(_ s: Double) -> String {
        guard s.isFinite, s >= 0 else { return "--:--" }
        let t = Int(s)
        if t >= 3600 {
            return String(format: "%d:%02d:%02d", t / 3600, (t % 3600) / 60, t % 60)
        }
        return String(format: "%02d:%02d", t / 60, t % 60)
    }
}
