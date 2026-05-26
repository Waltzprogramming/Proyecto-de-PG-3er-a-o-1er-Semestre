#pragma once

#include <string>

class AudioPlayer {
public:
    AudioPlayer() = default;
    AudioPlayer(const AudioPlayer&) = delete;
    AudioPlayer& operator=(const AudioPlayer&) = delete;
    ~AudioPlayer();

    bool open(const std::string& filePath);
    bool playLoop();
    void stop();
    void close();

private:
    std::wstring m_alias{L"bgm_loop"};
    bool m_open{false};
};
