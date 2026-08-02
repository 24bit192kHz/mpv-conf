#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <sys/resource.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <sys/wait.h>
#include <unistd.h>

#include <algorithm>
#include <cerrno>
#include <chrono>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <map>
#include <optional>
#include <regex>
#include <sstream>
#include <stdexcept>
#include <string>
#include <thread>
#include <utility>
#include <vector>

#include <nlohmann/json.hpp>

using json = nlohmann::json;
namespace fs = std::filesystem;

namespace {

constexpr const char* kDetectorVersion = "active-box-cfr-v5";
constexpr int kCropdetectPrerollFrames = 2;
constexpr int kCropdetectLetterboxHeightPad = 2;
constexpr int kEquivalentCropSizeTolerance = 8;
constexpr int kEquivalentCropOffsetTolerance = 4;
constexpr double kTransientRevertMaxSeconds = 0.10;

struct CropBox {
    int width = 0;
    int height = 0;
    int x = 0;
    int y = 0;
};

struct CropMarker {
    CropBox crop;
    double relative_seconds = 0.0;
    int votes = 0;
    int sampled_frames = 0;
    double remux_seconds = 0.0;
    double analyze_seconds = 0.0;
};

struct AnalyzerConfig {
    fs::path source;
    double start_seconds = 0.0;
    double duration_seconds = 10.0;
    double threshold = 26.0;
    int round_to = 2;
    int sample_step = 12;
    int min_votes = 3;
    int gpu_id = 0;
    std::optional<CropBox> current_crop;
};

struct ControllerConfig {
    fs::path mpv_socket;
    double interval_seconds = 0.25;
    double scan_ahead_seconds = 0.0;
    double duration_seconds = 3.0;
    double threshold = 2.0;
    int round_to = 2;
    int sample_step = 1;
    int min_votes = 2;
    int gpu_id = 0;
};

struct VideoSignal {
    int bit_depth = 8;
    bool limited_range = true;
};

struct ProcessResult {
    int status = 127;
    std::string stdout_text;
    std::string stderr_text;
};

class AppError : public std::runtime_error {
public:
    explicit AppError(const std::string& message) : std::runtime_error(message) {}
};

std::string format_seconds(double value);

double monotonic_seconds() {
    using clock = std::chrono::steady_clock;
    static const auto start = clock::now();
    const auto now = clock::now();
    return std::chrono::duration<double>(now - start).count();
}

std::string crop_string(const CropBox& crop) {
    return std::to_string(crop.width) + ":" + std::to_string(crop.height) + ":" +
           std::to_string(crop.x) + ":" + std::to_string(crop.y);
}

std::string mpv_filter_string(const CropBox& crop) {
    return "w=" + std::to_string(crop.width) + ":h=" + std::to_string(crop.height) +
           ":x=" + std::to_string(crop.x) + ":y=" + std::to_string(crop.y);
}

std::optional<CropBox> parse_crop(const std::string& value) {
    static const std::regex re(R"(^(\d+):(\d+):(\d+):(\d+)$)");
    std::smatch match;
    if (!std::regex_match(value, match, re)) {
        return std::nullopt;
    }
    return CropBox{
        std::stoi(match[1].str()),
        std::stoi(match[2].str()),
        std::stoi(match[3].str()),
        std::stoi(match[4].str()),
    };
}

bool equivalent_crop(const std::optional<CropBox>& left, const std::optional<CropBox>& right) {
    if (!left && !right) return true;
    if (!left || !right) return false;
    const CropBox& a = *left;
    const CropBox& b = *right;
    return std::abs(a.width - b.width) <= kEquivalentCropSizeTolerance &&
           std::abs(a.height - b.height) <= kEquivalentCropSizeTolerance &&
           std::abs(a.x - b.x) <= kEquivalentCropOffsetTolerance &&
           std::abs(a.y - b.y) <= kEquivalentCropOffsetTolerance;
}

bool executable_exists(const std::string& name) {
    const char* path_env = std::getenv("PATH");
    if (path_env == nullptr) return false;
    std::stringstream ss(path_env);
    std::string dir;
    while (std::getline(ss, dir, ':')) {
        fs::path candidate = fs::path(dir) / name;
        if (::access(candidate.c_str(), X_OK) == 0) return true;
    }
    return false;
}

std::vector<std::string> idle_command(std::vector<std::string> command) {
    if (executable_exists("chrt")) {
        std::vector<std::string> wrapped{"chrt", "-i", "0"};
        wrapped.insert(wrapped.end(), command.begin(), command.end());
        command = std::move(wrapped);
    }
    if (executable_exists("nice")) {
        std::vector<std::string> wrapped{"nice", "-n", "19"};
        wrapped.insert(wrapped.end(), command.begin(), command.end());
        command = std::move(wrapped);
    }
    if (executable_exists("ionice")) {
        std::vector<std::string> wrapped{"ionice", "-c", "3"};
        wrapped.insert(wrapped.end(), command.begin(), command.end());
        command = std::move(wrapped);
    }
    return command;
}

void close_fd(int fd) {
    if (fd >= 0) {
        while (::close(fd) == -1 && errno == EINTR) {}
    }
}

ProcessResult run_process(const std::vector<std::string>& command) {
    int stdout_pipe[2] = {-1, -1};
    int stderr_pipe[2] = {-1, -1};
    if (::pipe(stdout_pipe) == -1 || ::pipe(stderr_pipe) == -1) {
        throw AppError("pipe failed");
    }

    pid_t pid = ::fork();
    if (pid == -1) {
        close_fd(stdout_pipe[0]);
        close_fd(stdout_pipe[1]);
        close_fd(stderr_pipe[0]);
        close_fd(stderr_pipe[1]);
        throw AppError("fork failed");
    }

    if (pid == 0) {
        ::dup2(stdout_pipe[1], STDOUT_FILENO);
        ::dup2(stderr_pipe[1], STDERR_FILENO);
        close_fd(stdout_pipe[0]);
        close_fd(stdout_pipe[1]);
        close_fd(stderr_pipe[0]);
        close_fd(stderr_pipe[1]);

        std::vector<char*> argv;
        argv.reserve(command.size() + 1);
        for (const std::string& arg : command) {
            argv.push_back(const_cast<char*>(arg.c_str()));
        }
        argv.push_back(nullptr);
        ::execvp(argv[0], argv.data());
        _exit(127);
    }

    close_fd(stdout_pipe[1]);
    close_fd(stderr_pipe[1]);

    ProcessResult result;
    std::array<pollfd, 2> fds{{
        pollfd{stdout_pipe[0], POLLIN, 0},
        pollfd{stderr_pipe[0], POLLIN, 0},
    }};
    int open_count = 2;
    std::array<char, 8192> buffer{};
    while (open_count > 0) {
        int ready = ::poll(fds.data(), fds.size(), -1);
        if (ready == -1) {
            if (errno == EINTR) continue;
            break;
        }
        for (pollfd& fd : fds) {
            if (fd.fd < 0) continue;
            if ((fd.revents & (POLLIN | POLLHUP)) == 0) continue;
            while (true) {
                ssize_t count = ::read(fd.fd, buffer.data(), buffer.size());
                if (count > 0) {
                    if (fd.fd == stdout_pipe[0]) {
                        result.stdout_text.append(buffer.data(), static_cast<size_t>(count));
                    } else {
                        result.stderr_text.append(buffer.data(), static_cast<size_t>(count));
                    }
                    continue;
                }
                if (count == 0) {
                    close_fd(fd.fd);
                    fd.fd = -1;
                    --open_count;
                }
                break;
            }
        }
    }

    int status = 0;
    while (::waitpid(pid, &status, 0) == -1 && errno == EINTR) {}
    if (WIFEXITED(status)) {
        result.status = WEXITSTATUS(status);
    } else if (WIFSIGNALED(status)) {
        result.status = 128 + WTERMSIG(status);
    } else {
        result.status = 1;
    }
    return result;
}

std::vector<std::string> split_csv_line(const std::string& line) {
    std::vector<std::string> fields;
    std::string current;
    for (char ch : line) {
        if (ch == ',') {
            fields.push_back(current);
            current.clear();
        } else {
            current.push_back(ch);
        }
    }
    fields.push_back(current);
    return fields;
}

VideoSignal probe_video_signal(const fs::path& source) {
    ProcessResult result = run_process({
        "ffprobe",
        "-hide_banner",
        "-loglevel",
        "error",
        "-select_streams",
        "v:0",
        "-show_entries",
        "stream=pix_fmt,color_range",
        "-of",
        "csv=p=0",
        source.string(),
    });
    if (result.status != 0) {
        throw AppError("ffprobe failed: " + result.stderr_text);
    }
    std::istringstream lines(result.stdout_text);
    std::string line;
    if (!std::getline(lines, line)) {
        throw AppError("ffprobe returned no video stream");
    }
    std::vector<std::string> raw_fields = split_csv_line(line);
    std::vector<std::string> fields;
    for (const std::string& field : raw_fields) {
        if (!field.empty()) fields.push_back(field);
    }
    if (fields.empty()) {
        throw AppError("ffprobe returned invalid video signal");
    }

    int bit_depth = 8;
    static const std::regex bit_re(R"(p0?(10|12|14|16))");
    std::smatch match;
    if (std::regex_search(fields[0], match, bit_re)) {
        bit_depth = std::stoi(match[1].str());
    }
    const std::string color_range = fields.size() > 1 ? fields[1] : "tv";
    return VideoSignal{bit_depth, color_range == "tv"};
}

double cropdetect_limit(const AnalyzerConfig& config, const VideoSignal& signal) {
    if (!signal.limited_range) {
        return config.threshold;
    }
    return static_cast<double>(16 * (1 << std::max(0, signal.bit_depth - 8)));
}

std::string hwdownload_format(const VideoSignal& signal) {
    return signal.bit_depth > 8 ? "p010le" : "nv12";
}

std::vector<std::string> cropdetect_command(
    const AnalyzerConfig& config,
    const VideoSignal& signal,
    bool cuda
) {
    std::ostringstream limit;
    limit << cropdetect_limit(config, signal);
    std::string filters;
    if (cuda) {
        filters = "hwdownload,format=" + hwdownload_format(signal) + ",";
    }
    filters += "cropdetect=limit=" + limit.str() + ":round=" + std::to_string(config.round_to) +
               ":skip=" + std::to_string(kCropdetectPrerollFrames) + ":reset=1";

    std::vector<std::string> command{
        "ffmpeg",
        "-hide_banner",
        "-nostdin",
        "-loglevel",
        "info",
    };
    if (cuda) {
        command.insert(command.end(), {
            "-hwaccel",
            "cuda",
            "-hwaccel_output_format",
            "cuda",
        });
    }
    command.insert(command.end(), {
        "-ss",
        format_seconds(config.start_seconds),
        "-t",
        format_seconds(config.duration_seconds),
        "-i",
        config.source.string(),
        "-map",
        "0:v:0",
        "-an",
        "-sn",
        "-dn",
        "-vf",
        filters,
        "-f",
        "null",
        "-",
    });
    return idle_command(std::move(command));
}

std::string format_seconds(double value) {
    std::ostringstream out;
    out.setf(std::ios::fixed);
    out.precision(3);
    out << value;
    return out.str();
}

std::vector<std::pair<double, CropBox>> crop_samples(const std::string& stderr_text, int sample_step) {
    static const std::regex crop_re(R"(\bt:(\d+(?:\.\d+)?)\b.*\bcrop=(\d+:\d+:\d+:\d+))");
    std::vector<std::pair<double, CropBox>> samples;
    int frame_index = 0;
    for (std::sregex_iterator it(stderr_text.begin(), stderr_text.end(), crop_re), end; it != end; ++it) {
        if (frame_index % sample_step == 0) {
            auto crop = parse_crop((*it)[2].str());
            if (crop) {
                if (crop->x == 0 && crop->y > 0) {
                    crop->height += kCropdetectLetterboxHeightPad;
                }
                samples.emplace_back(std::stod((*it)[1].str()), *crop);
            }
        }
        ++frame_index;
    }
    return samples;
}

std::vector<CropMarker> suppress_transient_reverts(
    const std::vector<CropMarker>& markers,
    const std::optional<CropBox>& current_crop
) {
    std::vector<CropMarker> filtered;
    std::optional<CropBox> previous_crop = current_crop;
    size_t index = 0;
    while (index < markers.size()) {
        const CropMarker& current = markers[index];
        const CropMarker* following = index + 1 < markers.size() ? &markers[index + 1] : nullptr;
        if (following != nullptr &&
            equivalent_crop(std::optional<CropBox>(following->crop), previous_crop) &&
            following->relative_seconds - current.relative_seconds < kTransientRevertMaxSeconds) {
            index += 2;
            continue;
        }
        filtered.push_back(current);
        previous_crop = current.crop;
        ++index;
    }
    return filtered;
}

std::vector<CropMarker> stable_crop_markers(
    const std::vector<std::pair<double, CropBox>>& samples,
    int min_votes,
    const std::optional<CropBox>& current_crop
) {
    std::vector<CropMarker> markers;
    std::optional<CropBox> run_crop;
    double run_start = 0.0;
    int run_votes = 0;
    std::optional<CropBox> emitted_crop = current_crop;

    int sampled_frames = 0;
    for (const auto& [relative_seconds, crop] : samples) {
        ++sampled_frames;
        if (equivalent_crop(std::optional<CropBox>(crop), run_crop)) {
            ++run_votes;
        } else {
            run_crop = crop;
            run_start = relative_seconds;
            run_votes = 1;
        }

        if (run_votes >= min_votes && !equivalent_crop(std::optional<CropBox>(crop), emitted_crop)) {
            markers.push_back(CropMarker{
                crop,
                run_start,
                run_votes,
                sampled_frames,
                0.0,
                0.0,
            });
            emitted_crop = crop;
        }
    }
    return suppress_transient_reverts(markers, current_crop);
}

std::vector<CropMarker> analyze_timeline_events(const AnalyzerConfig& config) {
    const double started = monotonic_seconds();
    VideoSignal signal = probe_video_signal(config.source);
    ProcessResult result = run_process(cropdetect_command(config, signal, true));
    if (result.status != 0) {
        result = run_process(cropdetect_command(config, signal, false));
    }
    const double analyze_seconds = monotonic_seconds() - started;
    if (result.status != 0) {
        throw AppError("ffmpeg cropdetect failed: " + result.stderr_text);
    }
    std::vector<CropMarker> markers = stable_crop_markers(
        crop_samples(result.stderr_text, config.sample_step),
        config.min_votes,
        config.current_crop
    );
    for (CropMarker& marker : markers) {
        marker.remux_seconds = 0.0;
        marker.analyze_seconds = analyze_seconds;
    }
    return markers;
}

json marker_json(const CropMarker& marker) {
    return {
        {"detector_version", kDetectorVersion},
        {"crop", crop_string(marker.crop)},
        {"mpv_filter", mpv_filter_string(marker.crop)},
        {"votes", marker.votes},
        {"sampled_frames", marker.sampled_frames},
        {"remux_seconds", marker.remux_seconds},
        {"analyze_seconds", marker.analyze_seconds},
        {"relative_seconds", marker.relative_seconds},
    };
}

json markers_response(const std::vector<CropMarker>& markers) {
    json response = marker_json(markers.front());
    json events = json::array();
    for (const CropMarker& marker : markers) {
        events.push_back(marker_json(marker));
    }
    response["events"] = std::move(events);
    return response;
}

AnalyzerConfig parse_request_config(const json& raw) {
    AnalyzerConfig config;
    config.source = fs::path(raw.at("source").get<std::string>());
    config.start_seconds = raw.at("start").get<double>();
    config.duration_seconds = raw.at("duration").get<double>();
    config.threshold = raw.at("threshold").get<double>();
    config.round_to = raw.at("round_to").get<int>();
    config.sample_step = raw.at("sample_step").get<int>();
    config.min_votes = raw.at("min_votes").get<int>();
    config.gpu_id = raw.value("gpu_id", 0);
    if (raw.contains("current_crop") && !raw["current_crop"].is_null()) {
        if (!raw["current_crop"].is_string()) {
            throw AppError("request has invalid value types");
        }
        auto crop = parse_crop(raw["current_crop"].get<std::string>());
        if (!crop) {
            throw AppError("request has invalid value types");
        }
        config.current_crop = *crop;
    }
    return config;
}

std::string handle_request_line(const std::string& line) {
    try {
        json raw = json::parse(line);
        if (!raw.is_object()) {
            return json({{"ok", false}, {"error", "request must be a json object"}}).dump() + "\n";
        }
        AnalyzerConfig config = parse_request_config(raw);
        std::vector<CropMarker> markers = analyze_timeline_events(config);
        if (markers.empty()) {
            return json({{"ok", false}, {"error", "no stable crop found"}}).dump() + "\n";
        }
        json response = markers_response(markers);
        response["ok"] = true;
        return response.dump() + "\n";
    } catch (const json::parse_error&) {
        return json({{"ok", false}, {"error", "request is not valid json"}}).dump() + "\n";
    } catch (const json::out_of_range& exc) {
        std::string message = exc.what();
        return json({{"ok", false}, {"error", "missing request key"}}).dump() + "\n";
    } catch (const std::exception& exc) {
        return json({{"ok", false}, {"error", exc.what()}}).dump() + "\n";
    }
}

void lower_priority() {
    ::setpriority(PRIO_PROCESS, 0, 19);
    if (executable_exists("chrt")) {
        run_process({"chrt", "-i", "-p", "0", std::to_string(::getpid())});
    }
    if (executable_exists("ionice")) {
        run_process({"ionice", "-c", "3", "-p", std::to_string(::getpid())});
    }
}

void serve_daemon(const fs::path& socket_path, double idle_timeout_seconds) {
    lower_priority();
    int server_fd = ::socket(AF_UNIX, SOCK_STREAM, 0);
    if (server_fd == -1) {
        throw AppError("socket failed");
    }

    fs::remove(socket_path);
    sockaddr_un addr{};
    addr.sun_family = AF_UNIX;
    std::string path = socket_path.string();
    if (path.size() >= sizeof(addr.sun_path)) {
        close_fd(server_fd);
        throw AppError("socket path is too long");
    }
    std::strncpy(addr.sun_path, path.c_str(), sizeof(addr.sun_path) - 1);
    if (::bind(server_fd, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) == -1) {
        close_fd(server_fd);
        throw AppError("bind failed");
    }
    if (::listen(server_fd, 4) == -1) {
        close_fd(server_fd);
        fs::remove(socket_path);
        throw AppError("listen failed");
    }

    const auto idle_ms = static_cast<int>(std::max(1.0, idle_timeout_seconds) * 1000.0);
    while (true) {
        pollfd pfd{server_fd, POLLIN, 0};
        int ready = ::poll(&pfd, 1, idle_ms);
        if (ready == 0) break;
        if (ready == -1) {
            if (errno == EINTR) continue;
            break;
        }
        int client_fd = ::accept(server_fd, nullptr, nullptr);
        if (client_fd == -1) continue;
        std::string line;
        char ch = '\0';
        while (::read(client_fd, &ch, 1) == 1) {
            line.push_back(ch);
            if (ch == '\n') break;
        }
        std::string response = handle_request_line(line);
        ::send(client_fd, response.data(), response.size(), MSG_NOSIGNAL);
        close_fd(client_fd);
    }
    close_fd(server_fd);
    fs::remove(socket_path);
}

class MpvIpc {
public:
    explicit MpvIpc(fs::path socket_path) : socket_path_(std::move(socket_path)) {}

    ~MpvIpc() {
        close_fd(fd_);
    }

    void connect_socket() {
        sockaddr_un addr{};
        addr.sun_family = AF_UNIX;
        std::string path = socket_path_.string();
        if (path.size() >= sizeof(addr.sun_path)) throw AppError("mpv IPC socket path too long");
        std::strncpy(addr.sun_path, path.c_str(), sizeof(addr.sun_path) - 1);
        // Retry: mpv's input-ipc-server thread sets up listen() asynchronously.
        constexpr int kConnectAttempts = 40;
        constexpr auto kConnectSleep = std::chrono::milliseconds(50);
        int last_err = 0;
        for (int attempt = 1; ; ++attempt) {
            close_fd(fd_);
            fd_ = ::socket(AF_UNIX, SOCK_STREAM, 0);
            if (fd_ == -1) throw AppError("mpv IPC socket failed");
            if (::connect(fd_, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) == 0) {
                return;
            }
            last_err = errno;
            if (attempt >= kConnectAttempts) {
                throw AppError("mpv IPC connect failed after "
                               + std::to_string(attempt)
                               + " attempts: "
                               + std::strerror(last_err));
            }
            std::this_thread::sleep_for(kConnectSleep);
        }
    }

    json command(const json& command) {
        const int request_id = ++request_id_;
        json payload{{"command", command}, {"request_id", request_id}};
        std::string encoded = payload.dump() + "\n";
        if (::send(fd_, encoded.data(), encoded.size(), MSG_NOSIGNAL) == -1) {
            throw AppError("mpv IPC send failed");
        }

        while (true) {
            std::string line = read_line();
            if (line.empty()) throw AppError("mpv IPC returned no response");
            json response = json::parse(line);
            if (!response.is_object() || response.value("request_id", -1) != request_id) {
                continue;
            }
            return response;
        }
    }

private:
    std::string read_line() {
        std::string line;
        char ch = '\0';
        while (true) {
            ssize_t count = ::read(fd_, &ch, 1);
            if (count == 1) {
                line.push_back(ch);
                if (ch == '\n') return line;
                continue;
            }
            if (count == 0) return {};
            if (errno == EINTR) continue;
            throw AppError("mpv IPC read failed");
        }
    }

    fs::path socket_path_;
    int fd_ = -1;
    int request_id_ = 0;
};

std::optional<json> mpv_property(MpvIpc& client, const std::string& name) {
    json response = client.command(json::array({"get_property", name}));
    if (response.value("error", "") != "success" || !response.contains("data")) {
        return std::nullopt;
    }
    return response["data"];
}

bool scan_once(const ControllerConfig& config, MpvIpc& client, bool allow_paused) {
    auto path_value = mpv_property(client, "path");
    auto time_value = mpv_property(client, "time-pos");
    auto eof_value = mpv_property(client, "eof-reached");
    auto idle_value = mpv_property(client, "idle-active");
    auto core_idle_value = mpv_property(client, "core-idle");
    auto pause_value = mpv_property(client, "pause");
    if (!path_value || !path_value->is_string() || !time_value || !time_value->is_number()) {
        return false;
    }
    const bool eof_reached = eof_value && eof_value->is_boolean() && eof_value->get<bool>();
    const bool idle_active = idle_value && idle_value->is_boolean() && idle_value->get<bool>();
    const bool core_idle = core_idle_value && core_idle_value->is_boolean() && core_idle_value->get<bool>();
    const bool paused = pause_value && pause_value->is_boolean() && pause_value->get<bool>();
    if (eof_reached || idle_active) {
        throw AppError("controller finished");
    }
    if ((core_idle || paused) && !allow_paused) {
        return false;
    }

    const double scan_start = time_value->get<double>() + config.scan_ahead_seconds;
    AnalyzerConfig analyzer{
        fs::path(path_value->get<std::string>()),
        scan_start,
        config.duration_seconds,
        config.threshold,
        config.round_to,
        config.sample_step,
        config.min_votes,
        config.gpu_id,
        std::nullopt,
    };

    json response;
    try {
        std::vector<CropMarker> markers = analyze_timeline_events(analyzer);
        if (markers.empty()) {
            response = json{{"ok", false}, {"error", "no stable crop found"}};
        } else {
            response = markers_response(markers);
            response["ok"] = true;
        }
    } catch (const std::exception& exc) {
        response = json{{"ok", false}, {"error", exc.what()}};
    }

    client.command(json::array({
        "script-message-to",
        "dynamic_crop",
        "timeline-events",
        response.dump(),
        format_seconds(scan_start),
    }));
    return true;
}

void run_controller(const ControllerConfig& config) {
    try {
        lower_priority();
        MpvIpc client(config.mpv_socket);
        client.connect_socket();
        bool first_scan_sent = false;
        while (true) {
            bool sent = scan_once(config, client, !first_scan_sent);
            first_scan_sent = first_scan_sent || sent;
            std::this_thread::sleep_for(std::chrono::duration<double>(config.interval_seconds));
        }
    } catch (const std::exception& exc) {
        std::cerr << "cuda-crop-cpp controller exited: " << exc.what() << "\n";
    } catch (...) {
        std::cerr << "cuda-crop-cpp controller exited: unknown exception\n";
    }
}

std::optional<std::string> option_value(int& index, int argc, char** argv) {
    if (index + 1 >= argc) return std::nullopt;
    ++index;
    return std::string(argv[index]);
}

int run_analyze(int argc, char** argv) {
    if (argc < 3) return 2;
    AnalyzerConfig config;
    config.source = argv[2];
    bool timing = false;
    for (int i = 3; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--timing") {
            timing = true;
            continue;
        }
        auto value = option_value(i, argc, argv);
        if (!value) break;
        if (arg == "--start") config.start_seconds = std::stod(*value);
        else if (arg == "--duration") config.duration_seconds = std::stod(*value);
        else if (arg == "--threshold") config.threshold = std::stod(*value);
        else if (arg == "--round-to") config.round_to = std::stoi(*value);
        else if (arg == "--sample-step") config.sample_step = std::stoi(*value);
        else if (arg == "--min-votes") config.min_votes = std::stoi(*value);
        else if (arg == "--gpu-id") config.gpu_id = std::stoi(*value);
    }
    std::vector<CropMarker> markers = analyze_timeline_events(config);
    if (markers.empty()) return 2;
    const CropMarker& marker = markers.front();
    json response{
        {"crop", crop_string(marker.crop)},
        {"mpv_filter", mpv_filter_string(marker.crop)},
        {"votes", marker.votes},
        {"sampled_frames", marker.sampled_frames},
        {"remux_seconds", timing ? json(marker.remux_seconds) : json(nullptr)},
        {"analyze_seconds", timing ? json(marker.analyze_seconds) : json(nullptr)},
    };
    std::cout << response.dump(2) << "\n";
    return 0;
}

int run_daemon(int argc, char** argv) {
    fs::path socket_path = "/tmp/cuda-crop-py.sock";
    double idle_timeout = 10.0;
    for (int i = 2; i < argc; ++i) {
        std::string arg = argv[i];
        auto value = option_value(i, argc, argv);
        if (!value) break;
        if (arg == "--socket-path") socket_path = *value;
        else if (arg == "--idle-timeout") idle_timeout = std::stod(*value);
    }
    serve_daemon(socket_path, idle_timeout);
    return 0;
}

int run_controller_command(int argc, char** argv) {
    ControllerConfig config;
    for (int i = 2; i < argc; ++i) {
        std::string arg = argv[i];
        auto value = option_value(i, argc, argv);
        if (!value) break;
        if (arg == "--mpv-socket") config.mpv_socket = *value;
        else if (arg == "--interval") config.interval_seconds = std::stod(*value);
        else if (arg == "--scan-ahead") config.scan_ahead_seconds = std::stod(*value);
        else if (arg == "--duration") config.duration_seconds = std::stod(*value);
        else if (arg == "--threshold") config.threshold = std::stod(*value);
        else if (arg == "--round-to") config.round_to = std::stoi(*value);
        else if (arg == "--sample-step") config.sample_step = std::stoi(*value);
        else if (arg == "--min-votes") config.min_votes = std::stoi(*value);
        else if (arg == "--gpu-id") config.gpu_id = std::stoi(*value);
    }
    if (config.mpv_socket.empty()) {
        return 2;
    }
    run_controller(config);
    return 0;
}

}

int main(int argc, char** argv) {
    if (argc < 2) {
        std::cerr << "usage: cuda-crop-cpp <analyze|daemon|controller>\n";
        return 2;
    }
    try {
        std::string command = argv[1];
        if (command == "analyze") return run_analyze(argc, argv);
        if (command == "daemon") return run_daemon(argc, argv);
        if (command == "controller") return run_controller_command(argc, argv);
        std::cerr << "unknown command: " << command << "\n";
        return 2;
    } catch (const std::exception& exc) {
        std::cerr << exc.what() << "\n";
        return 1;
    }
}
