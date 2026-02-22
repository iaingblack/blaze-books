import SwiftUI

/// In-reader voice selection sheet for choosing TTS voices.
///
/// Displays installed English voices grouped by quality tier with tap-to-select and
/// speaker-icon preview. Includes a guidance card for downloading additional voices
/// since Apple provides no API to enumerate uninstalled voices.
///
/// **Locked decisions from CONTEXT.md:**
/// - Accessible from within the reading view (in-reader settings)
/// - Tap a voice row to select it; tap speaker icon to preview
/// - Two sections: "Installed" voices and "Available for Download" guidance
/// - Flat list of English voices only for v1
/// - Fixed sample phrase for voice comparison
struct VoicePickerView: View {

    /// The voice manager providing installed voices and preview/selection functionality.
    var voiceManager: VoiceManager

    /// Called when the user selects a voice, passing the selected VoiceInfo.
    var onVoiceSelected: (VoiceInfo) -> Void

    /// Controls sheet dismissal.
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Installed Voices Section
                Section {
                    if voiceManager.installedVoices.isEmpty {
                        Text("No English voices found")
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        ForEach(voiceManager.installedVoices) { voice in
                            voiceRow(voice)
                        }
                    }
                } header: {
                    Text("Installed")
                }

                // MARK: - Download Guidance Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label {
                            Text("Download enhanced voices for better quality")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        } icon: {
                            Image(systemName: "arrow.down.circle")
                                .foregroundStyle(.blue)
                        }

                        Text("In Settings, go to:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Accessibility → Read & Speak → Voices → English - Voice")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        Text("Choose a voice and tap the download icon next to it. After downloading, return here and new voices will appear automatically.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button {
                            voiceManager.openVoiceSettings()
                        } label: {
                            Label("Open Accessibility Settings", systemImage: "gear")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Available for Download")
                }
            }
            .navigationTitle("Voices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Voice Row

    /// A row displaying a single voice with name, quality badge, selection checkmark,
    /// and preview button.
    private func voiceRow(_ voice: VoiceInfo) -> some View {
        HStack {
            // Voice info
            VStack(alignment: .leading, spacing: 2) {
                Text(voice.name)
                    .font(.body)

                HStack(spacing: 6) {
                    // Language tag
                    Text(voice.language)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    // Quality badge for enhanced/premium
                    if voice.quality != .default {
                        Text(voice.quality.rawValue.capitalized)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(qualityBadgeColor(voice.quality).opacity(0.15))
                            .foregroundStyle(qualityBadgeColor(voice.quality))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            // Selection checkmark
            if voiceManager.selectedVoice?.identifier == voice.identifier {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
                    .fontWeight(.semibold)
            }

            // Preview button
            Button {
                voiceManager.previewVoice(voice)
            } label: {
                Image(systemName: "speaker.wave.2")
                    .foregroundStyle(.blue)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            voiceManager.selectVoice(voice)
            onVoiceSelected(voice)
        }
    }

    /// Returns the badge color for a voice quality tier.
    private func qualityBadgeColor(_ quality: VoiceInfo.Quality) -> Color {
        switch quality {
        case .premium:
            return .purple
        case .enhanced:
            return .blue
        case .default:
            return .gray
        }
    }
}
