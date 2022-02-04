//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2022 Jellyfin & Jellyfin Contributors
//

import Algorithms
import Combine
import Defaults
import Foundation
import JellyfinAPI
import UIKit

#if os(tvOS)
	import TVVLCKit
#else
	import MobileVLCKit
#endif

final class VideoPlayerViewModel: ViewModel {

	// MARK: Published

	// Manually kept state because VLCKit doesn't properly set "played"
	// on the VLCMediaPlayer object
	@Published
	var playerState: VLCMediaPlayerState = .buffering
	@Published
	var leftLabelText: String = "--:--"
	@Published
	var rightLabelText: String = "--:--"
	@Published
	var playbackSpeed: PlaybackSpeed = .one
	@Published
	var subtitlesEnabled: Bool {
		didSet {
			if syncSubtitleStateWithAdjacent {
				previousItemVideoPlayerViewModel?.matchSubtitlesEnabled(with: self)
				nextItemVideoPlayerViewModel?.matchSubtitlesEnabled(with: self)
			}
		}
	}

	@Published
	var selectedAudioStreamIndex: Int
	@Published
	var selectedSubtitleStreamIndex: Int {
		didSet {
			if syncSubtitleStateWithAdjacent {
				previousItemVideoPlayerViewModel?.matchSubtitleStream(with: self)
				nextItemVideoPlayerViewModel?.matchSubtitleStream(with: self)
			}
		}
	}

	@Published
	var previousItemVideoPlayerViewModel: VideoPlayerViewModel?
	@Published
	var nextItemVideoPlayerViewModel: VideoPlayerViewModel?
	@Published
	var jumpBackwardLength: VideoPlayerJumpLength {
		willSet {
			Defaults[.videoPlayerJumpBackward] = newValue
		}
	}

	@Published
	var jumpForwardLength: VideoPlayerJumpLength {
		willSet {
			Defaults[.videoPlayerJumpForward] = newValue
		}
	}

	@Published
	var sliderIsScrubbing: Bool = false
	@Published
	var sliderPercentage: Double = 0 {
		willSet {
			sliderScrubbingSubject.send(self)
			sliderPercentageChanged(newValue: newValue)
		}
	}

	@Published
	var autoplayEnabled: Bool {
		willSet {
			previousItemVideoPlayerViewModel?.autoplayEnabled = newValue
			nextItemVideoPlayerViewModel?.autoplayEnabled = newValue
			Defaults[.autoplayEnabled] = newValue
		}
	}

	@Published
	var mediaItems: [BaseItemDto.ItemDetail]

	// MARK: ShouldShowItems

	let shouldShowPlayPreviousItem: Bool
	let shouldShowPlayNextItem: Bool
	let shouldShowAutoPlay: Bool
	let shouldShowJumpButtonsInOverlayMenu: Bool

	// MARK: General

	private(set) var item: BaseItemDto
    private(set) var networkType: PlayerNetworkType
	let title: String
	let subtitle: String?
	let directStreamURL: URL
	let transcodedStreamURL: URL?
    let localFileURL: URL?
	let hlsStreamURL: URL
	let audioStreams: [MediaStream]
	let subtitleStreams: [MediaStream]
	let chapters: [ChapterInfo]
	let overlayType: OverlayType
	let jumpGesturesEnabled: Bool
	let resumeOffset: Bool
	let streamType: ServerStreamType
	let container: String
	let filename: String?
    let fileSize: Int64?
	let versionName: String?

	// MARK: Experimental

	let syncSubtitleStateWithAdjacent: Bool

	// MARK: tvOS

	let confirmClose: Bool

	// Full response kept for convenience
	let response: PlaybackInfoResponse

	var playerOverlayDelegate: PlayerOverlayDelegate?

	// Ticks of the time the media began playing
	private var startTimeTicks: Int64 = 0

	// MARK: Current Time

	var currentSeconds: Double {
		let runTimeTicks = item.runTimeTicks ?? 0
		let videoDuration = Double(runTimeTicks / 10_000_000)
		return round(sliderPercentage * videoDuration)
	}

	var currentSecondTicks: Int64 {
		Int64(currentSeconds) * 10_000_000
	}

	func setSeconds(_ seconds: Int64) {
		let videoDuration = item.runTimeTicks!
		let percentage = Double(seconds * 10_000_000) / Double(videoDuration)

		sliderPercentage = percentage
	}

	// MARK: Helpers

	var currentAudioStream: MediaStream? {
		audioStreams.first(where: { $0.index == selectedAudioStreamIndex })
	}

	var currentSubtitleStream: MediaStream? {
		subtitleStreams.first(where: { $0.index == selectedSubtitleStreamIndex })
	}

	var currentChapter: ChapterInfo? {

		let chapterPairs = chapters.adjacentPairs().map { ($0, $1) }
		let chapterRanges = chapterPairs.map { ($0.startPositionTicks ?? 0, ($1.startPositionTicks ?? 1) - 1) }

		for chapterRangeIndex in 0 ..< chapterRanges.count {
			if chapterRanges[chapterRangeIndex].0 <= currentSecondTicks &&
				currentSecondTicks < chapterRanges[chapterRangeIndex].1
			{
				return chapterPairs[chapterRangeIndex].0
			}
		}

		return nil
	}
    
    var friendlyStorage: String? {
        guard let fileSize = fileSize else { return nil }

        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.countStyle = .file
        return byteCountFormatter.string(fromByteCount: fileSize)
    }

	// Necessary PassthroughSubject to capture manual scrubbing from sliders
	let sliderScrubbingSubject = PassthroughSubject<VideoPlayerViewModel, Never>()

	// During scrubbing, many progress reports were spammed
	// Send only the current report after a delay
	private var progressReportTimer: Timer?
	private var lastProgressReport: PlaybackProgressInfo?

	// MARK: init

	init(item: BaseItemDto,
         networkType: PlayerNetworkType = .online,
	     title: String,
	     subtitle: String?,
	     directStreamURL: URL,
	     transcodedStreamURL: URL?,
	     hlsStreamURL: URL,
	     streamType: ServerStreamType,
	     response: PlaybackInfoResponse,
	     audioStreams: [MediaStream],
	     subtitleStreams: [MediaStream],
	     chapters: [ChapterInfo],
	     selectedAudioStreamIndex: Int,
	     selectedSubtitleStreamIndex: Int,
	     subtitlesEnabled: Bool,
	     autoplayEnabled: Bool,
	     overlayType: OverlayType,
	     shouldShowPlayPreviousItem: Bool,
	     shouldShowPlayNextItem: Bool,
	     shouldShowAutoPlay: Bool,
	     container: String,
	     filename: String?,
         fileSize: Int64?,
	     versionName: String?)
	{
		self.item = item
        self.networkType = networkType
		self.title = title
		self.subtitle = subtitle
		self.directStreamURL = directStreamURL
		self.transcodedStreamURL = transcodedStreamURL
		self.hlsStreamURL = hlsStreamURL
		self.streamType = streamType
		self.response = response
		self.audioStreams = audioStreams
		self.subtitleStreams = subtitleStreams
		self.chapters = chapters
		self.selectedAudioStreamIndex = selectedAudioStreamIndex
		self.selectedSubtitleStreamIndex = selectedSubtitleStreamIndex
		self.subtitlesEnabled = subtitlesEnabled
		self.autoplayEnabled = autoplayEnabled
		self.overlayType = overlayType
		self.shouldShowPlayPreviousItem = shouldShowPlayPreviousItem
		self.shouldShowPlayNextItem = shouldShowPlayNextItem
		self.shouldShowAutoPlay = shouldShowAutoPlay
		self.container = container
		self.filename = filename
        self.fileSize = fileSize
		self.versionName = versionName

		self.jumpBackwardLength = Defaults[.videoPlayerJumpBackward]
		self.jumpForwardLength = Defaults[.videoPlayerJumpForward]
		self.jumpGesturesEnabled = Defaults[.jumpGesturesEnabled]
		self.shouldShowJumpButtonsInOverlayMenu = Defaults[.shouldShowJumpButtonsInOverlayMenu]

		self.resumeOffset = Defaults[.resumeOffset]

		self.syncSubtitleStateWithAdjacent = Defaults[.Experimental.syncSubtitleStateWithAdjacent]

		self.confirmClose = Defaults[.confirmClose]

		self.mediaItems = item.createMediaItems()
        
        var potentialLocalFileURL: URL? = nil
        
        if let filename = filename {
            if DownloadManager.main.hasLocalFile(for: item, fileName: filename) {
                potentialLocalFileURL = DownloadManager.main.localFileURL(for: item, fileName: filename)
            }
        }
        
        self.localFileURL = potentialLocalFileURL

		super.init()

		self.sliderPercentage = (item.userData?.playedPercentage ?? 0) / 100
	}

	private func sliderPercentageChanged(newValue: Double) {
		let runTimeTicks = item.runTimeTicks ?? 0
		let videoDuration = Double(runTimeTicks / 10_000_000)
		let secondsScrubbedRemaining = videoDuration - currentSeconds

		leftLabelText = calculateTimeText(from: currentSeconds)
		rightLabelText = calculateTimeText(from: secondsScrubbedRemaining)
	}

	private func calculateTimeText(from duration: Double) -> String {
		let hours = floor(duration / 3600)
		let minutes = duration.truncatingRemainder(dividingBy: 3600) / 60
		let seconds = duration.truncatingRemainder(dividingBy: 3600).truncatingRemainder(dividingBy: 60)

		let timeText: String

		if hours != 0 {
			timeText =
				"\(Int(hours)):\(String(Int(floor(minutes))).leftPad(toWidth: 2, withString: "0")):\(String(Int(floor(seconds))).leftPad(toWidth: 2, withString: "0"))"
		} else {
			timeText =
				"\(String(Int(floor(minutes))).leftPad(toWidth: 2, withString: "0")):\(String(Int(floor(seconds))).leftPad(toWidth: 2, withString: "0"))"
		}

		return timeText
	}
}

// MARK: Injected Values

extension VideoPlayerViewModel {

	// Injects custom values that override certain settings
	func injectCustomValues(startFromBeginning: Bool = false) {

		if startFromBeginning {
			item.userData?.playbackPositionTicks = 0
			item.userData?.playedPercentage = 0
			sliderPercentage = 0
			sliderPercentageChanged(newValue: 0)
		}
	}
    
    func setNetworkType(_ networkType: PlayerNetworkType) {
        self.networkType = networkType
    }
}

// MARK: Adjacent Items

extension VideoPlayerViewModel {

	func getAdjacentEpisodes() {
        guard networkType == .online else { return }
		guard let seriesID = item.seriesId, item.itemType == .episode else { return }

		TvShowsAPI.getEpisodes(seriesId: seriesID,
		                       userId: SessionManager.main.currentLogin.user.id,
		                       adjacentTo: item.id,
		                       limit: 3)
			.sink(receiveCompletion: { completion in
				self.handleAPIRequestError(completion: completion)
			}, receiveValue: { response in

				// 4 possible states:
				//  1 - only current episode
				//  2 - two episodes with next episode
				//  3 - two episodes with previous episode
				//  4 - three episodes with current in middle

				// State 1
				guard let items = response.items, items.count > 1 else { return }

				if items.count == 2 {
					if items[0].id == self.item.id {
						// State 2
						let nextItem = items[1]

						nextItem.createVideoPlayerViewModel()
							.sink { completion in
								self.handleAPIRequestError(completion: completion)
							} receiveValue: { viewModels in
								for viewModel in viewModels {
									viewModel.matchSubtitleStream(with: self)
									viewModel.matchAudioStream(with: self)
								}

								self.nextItemVideoPlayerViewModel = viewModels.first
							}
							.store(in: &self.cancellables)
					} else {
						// State 3
						let previousItem = items[0]

						previousItem.createVideoPlayerViewModel()
							.sink { completion in
								self.handleAPIRequestError(completion: completion)
							} receiveValue: { viewModels in
								for viewModel in viewModels {
									viewModel.matchSubtitleStream(with: self)
									viewModel.matchAudioStream(with: self)
								}

								self.previousItemVideoPlayerViewModel = viewModels.first
							}
							.store(in: &self.cancellables)
					}
				} else {
					// State 4

					let previousItem = items[0]
					let nextItem = items[2]

					previousItem.createVideoPlayerViewModel()
						.sink { completion in
							self.handleAPIRequestError(completion: completion)
						} receiveValue: { viewModels in
							for viewModel in viewModels {
								viewModel.matchSubtitleStream(with: self)
								viewModel.matchAudioStream(with: self)
							}

							self.previousItemVideoPlayerViewModel = viewModels.first
						}
						.store(in: &self.cancellables)

					nextItem.createVideoPlayerViewModel()
						.sink { completion in
							self.handleAPIRequestError(completion: completion)
						} receiveValue: { viewModels in
							for viewModel in viewModels {
								viewModel.matchSubtitleStream(with: self)
								viewModel.matchAudioStream(with: self)
							}

							self.nextItemVideoPlayerViewModel = viewModels.first
						}
						.store(in: &self.cancellables)
				}
			})
			.store(in: &cancellables)
	}

	// Potential for experimental feature of syncing subtitle states among adjacent episodes
	// when using previous & next item buttons and auto-play

	private func matchSubtitleStream(with masterViewModel: VideoPlayerViewModel) {
		if !masterViewModel.subtitlesEnabled {
			matchSubtitlesEnabled(with: masterViewModel)
		}

		guard let masterSubtitleStream = masterViewModel.subtitleStreams
			.first(where: { $0.index == masterViewModel.selectedSubtitleStreamIndex }),
			let matchingSubtitleStream = self.subtitleStreams.first(where: { mediaStreamAboutEqual($0, masterSubtitleStream) }),
			let matchingSubtitleStreamIndex = matchingSubtitleStream.index else { return }

		self.selectedSubtitleStreamIndex = matchingSubtitleStreamIndex
	}

	private func matchAudioStream(with masterViewModel: VideoPlayerViewModel) {
		guard let currentAudioStream = masterViewModel.audioStreams.first(where: { $0.index == masterViewModel.selectedAudioStreamIndex }),
		      let matchingAudioStream = self.audioStreams.first(where: { mediaStreamAboutEqual($0, currentAudioStream) }) else { return }

		self.selectedAudioStreamIndex = matchingAudioStream.index ?? -1
	}

	private func matchSubtitlesEnabled(with masterViewModel: VideoPlayerViewModel) {
		self.subtitlesEnabled = masterViewModel.subtitlesEnabled
	}

	private func mediaStreamAboutEqual(_ lhs: MediaStream, _ rhs: MediaStream) -> Bool {
		lhs.displayTitle == rhs.displayTitle && lhs.language == rhs.language
	}
}

// MARK: Progress Report Timer

extension VideoPlayerViewModel {

	private func sendNewProgressReportWithTimer() {
		self.progressReportTimer?.invalidate()
		self.progressReportTimer = Timer.scheduledTimer(timeInterval: 0.7, target: self, selector: #selector(_sendProgressReport),
		                                                userInfo: nil, repeats: false)
	}
}

// MARK: Updates

extension VideoPlayerViewModel {

	// MARK: sendPlayReport

	func sendPlayReport() {
        guard networkType == .online else { return }

		self.startTimeTicks = Int64(Date().timeIntervalSince1970) * 10_000_000

		let subtitleStreamIndex = subtitlesEnabled ? selectedSubtitleStreamIndex : nil

		let startInfo = PlaybackStartInfo(canSeek: true,
		                                  item: item,
		                                  itemId: item.id,
		                                  sessionId: response.playSessionId,
		                                  mediaSourceId: item.id,
		                                  audioStreamIndex: selectedAudioStreamIndex,
		                                  subtitleStreamIndex: subtitleStreamIndex,
		                                  isPaused: false,
		                                  isMuted: false,
		                                  positionTicks: item.userData?.playbackPositionTicks,
		                                  playbackStartTimeTicks: startTimeTicks,
		                                  volumeLevel: 100,
		                                  brightness: 100,
		                                  aspectRatio: nil,
		                                  playMethod: .directPlay,
		                                  liveStreamId: nil,
		                                  playSessionId: response.playSessionId,
		                                  repeatMode: .repeatNone,
		                                  nowPlayingQueue: nil,
		                                  playlistItemId: "playlistItem0")

		PlaystateAPI.reportPlaybackStart(playbackStartInfo: startInfo)
			.sink { completion in
				self.handleAPIRequestError(completion: completion)
			} receiveValue: { _ in
				LogManager.shared.log.debug("Start report sent for item: \(self.item.id ?? "No ID")")
			}
			.store(in: &cancellables)
	}

	// MARK: sendPauseReport

	func sendPauseReport(paused: Bool) {
        guard networkType == .online else { return }

		let subtitleStreamIndex = subtitlesEnabled ? selectedSubtitleStreamIndex : nil

		let pauseInfo = PlaybackStartInfo(canSeek: true,
		                                  item: item,
		                                  itemId: item.id,
		                                  sessionId: response.playSessionId,
		                                  mediaSourceId: item.id,
		                                  audioStreamIndex: selectedAudioStreamIndex,
		                                  subtitleStreamIndex: subtitleStreamIndex,
		                                  isPaused: paused,
		                                  isMuted: false,
		                                  positionTicks: currentSecondTicks,
		                                  playbackStartTimeTicks: startTimeTicks,
		                                  volumeLevel: 100,
		                                  brightness: 100,
		                                  aspectRatio: nil,
		                                  playMethod: .directPlay,
		                                  liveStreamId: nil,
		                                  playSessionId: response.playSessionId,
		                                  repeatMode: .repeatNone,
		                                  nowPlayingQueue: nil,
		                                  playlistItemId: "playlistItem0")

		PlaystateAPI.reportPlaybackStart(playbackStartInfo: pauseInfo)
			.sink { completion in
				self.handleAPIRequestError(completion: completion)
			} receiveValue: { _ in
				LogManager.shared.log.debug("Pause report sent for item: \(self.item.id ?? "No ID")")
			}
			.store(in: &cancellables)
	}

	// MARK: sendProgressReport

	func sendProgressReport() {
        guard networkType == .online else { return }

		let subtitleStreamIndex = subtitlesEnabled ? selectedSubtitleStreamIndex : nil

		let progressInfo = PlaybackProgressInfo(canSeek: true,
		                                        item: item,
		                                        itemId: item.id,
		                                        sessionId: response.playSessionId,
		                                        mediaSourceId: item.id,
		                                        audioStreamIndex: selectedAudioStreamIndex,
		                                        subtitleStreamIndex: subtitleStreamIndex,
		                                        isPaused: false,
		                                        isMuted: false,
		                                        positionTicks: currentSecondTicks,
		                                        playbackStartTimeTicks: startTimeTicks,
		                                        volumeLevel: nil,
		                                        brightness: nil,
		                                        aspectRatio: nil,
		                                        playMethod: .directPlay,
		                                        liveStreamId: nil,
		                                        playSessionId: response.playSessionId,
		                                        repeatMode: .repeatNone,
		                                        nowPlayingQueue: nil,
		                                        playlistItemId: "playlistItem0")

		self.lastProgressReport = progressInfo

		self.sendNewProgressReportWithTimer()
	}

	@objc
	private func _sendProgressReport() {
		guard let lastProgressReport = lastProgressReport else { return }

		PlaystateAPI.reportPlaybackProgress(playbackProgressInfo: lastProgressReport)
			.sink { completion in
				self.handleAPIRequestError(completion: completion)
			} receiveValue: { _ in
				LogManager.shared.log.debug("Playback progress sent for item: \(self.item.id ?? "No ID")")
			}
			.store(in: &cancellables)

		self.lastProgressReport = nil
	}

	// MARK: sendStopReport

	func sendStopReport() {
        guard networkType == .online else { return }

		let stopInfo = PlaybackStopInfo(item: item,
		                                itemId: item.id,
		                                sessionId: response.playSessionId,
		                                mediaSourceId: item.id,
		                                positionTicks: currentSecondTicks,
		                                liveStreamId: nil,
		                                playSessionId: response.playSessionId,
		                                failed: nil,
		                                nextMediaType: nil,
		                                playlistItemId: "playlistItem0",
		                                nowPlayingQueue: nil)

		PlaystateAPI.reportPlaybackStopped(playbackStopInfo: stopInfo)
			.sink { completion in
				self.handleAPIRequestError(completion: completion)
			} receiveValue: { _ in
				LogManager.shared.log.debug("Stop report sent for item: \(self.item.id ?? "No ID")")
                Notifications[.didSendStopReport].post(object: self.item.id)
			}
			.store(in: &cancellables)
	}
}

// MARK: Embedded/Normal Subtitle Streams

extension VideoPlayerViewModel {

	func createEmbeddedSubtitleStream(with subtitleStream: MediaStream) -> URL {

		guard let baseURL = URLComponents(url: directStreamURL, resolvingAgainstBaseURL: false) else { fatalError() }
		guard let queryItems = baseURL.queryItems else { fatalError() }

		var newURL = baseURL
		var newQueryItems = queryItems

		newQueryItems.removeAll(where: { $0.name == "SubtitleStreamIndex" })
		newQueryItems.removeAll(where: { $0.name == "SubtitleMethod" })

		newURL.addQueryItem(name: "SubtitleMethod", value: "Encode")
		newURL.addQueryItem(name: "SubtitleStreamIndex", value: "\(subtitleStream.index ?? -1)")

		return newURL.url!
	}
}

// MARK: Equatable

extension VideoPlayerViewModel: Equatable {

	static func == (lhs: VideoPlayerViewModel, rhs: VideoPlayerViewModel) -> Bool {
		lhs.item.id == rhs.item.id &&
			lhs.item.userData?.playbackPositionTicks == rhs.item.userData?.playbackPositionTicks
	}
}

// MARK: Hashable

extension VideoPlayerViewModel: Hashable {

	func hash(into hasher: inout Hasher) {
		hasher.combine(item)
		hasher.combine(directStreamURL)
		hasher.combine(filename)
		hasher.combine(versionName)
	}
}
