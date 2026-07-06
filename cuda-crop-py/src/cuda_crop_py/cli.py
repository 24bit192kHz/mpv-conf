from pathlib import Path
from typing import Annotated, Final

import typer
from rich.console import Console

from cuda_crop_py.controller import ControllerConfig, run_controller
from cuda_crop_py.model import AnalyzerConfig
from cuda_crop_py.server import ProtocolError, serve

app = typer.Typer(no_args_is_help=True)
console = Console()
DEFAULT_SOCKET_PATH: Final = Path("/tmp/cuda-crop-py.sock")  # noqa: S108
SocketPathOption = Annotated[Path, typer.Option()]


@app.command()
def analyze(
    source: Path,
    start: float = typer.Option(0.0, min=0.0),
    duration: float = typer.Option(10.0, min=0.1),
    threshold: float = typer.Option(26.0, min=0.0),
    round_to: int = typer.Option(2, min=1),
    sample_step: int = typer.Option(12, min=1),
    min_votes: int = typer.Option(3, min=1),
    gpu_id: int = typer.Option(0, min=0),
    timing: bool = typer.Option(default=False),
) -> None:
    from cuda_crop_py.cuda_detect import analyze_source

    config = AnalyzerConfig(
        source=source,
        start_seconds=start,
        duration_seconds=duration,
        threshold=threshold,
        round_to=round_to,
        sample_step=sample_step,
        min_votes=min_votes,
        gpu_id=gpu_id,
    )
    vote = analyze_source(config)
    if vote is None:
        raise typer.Exit(code=2)
    console.print_json(
        data={
            "crop": vote.crop.ffmpeg_crop(),
            "mpv_filter": vote.crop.mpv_filter(),
            "votes": vote.votes,
            "sampled_frames": vote.sampled_frames,
            "remux_seconds": vote.remux_seconds if timing else None,
            "analyze_seconds": vote.analyze_seconds if timing else None,
        },
    )


@app.command()
def daemon(
    socket_path: SocketPathOption = DEFAULT_SOCKET_PATH,
    idle_timeout: Annotated[float, typer.Option(min=1.0)] = 10.0,
) -> None:
    try:
        serve(socket_path, idle_timeout)
    except ProtocolError as exc:
        if exc.message != "server already active":
            raise


@app.command()
def controller(
    mpv_socket: Annotated[Path, typer.Option()],
    interval: Annotated[float, typer.Option(min=0.1)] = 0.25,
    scan_ahead: Annotated[float, typer.Option()] = 0.0,
    duration: Annotated[float, typer.Option(min=0.1)] = 3.0,
    threshold: Annotated[float, typer.Option(min=0.0)] = 2.0,
    round_to: Annotated[int, typer.Option(min=1)] = 2,
    sample_step: Annotated[int, typer.Option(min=1)] = 1,
    min_votes: Annotated[int, typer.Option(min=1)] = 2,
    gpu_id: Annotated[int, typer.Option(min=0)] = 0,
) -> None:
    run_controller(
        ControllerConfig(
            mpv_socket=mpv_socket,
            interval_seconds=interval,
            scan_ahead_seconds=scan_ahead,
            duration_seconds=duration,
            threshold=threshold,
            round_to=round_to,
            sample_step=sample_step,
            min_votes=min_votes,
            gpu_id=gpu_id,
        ),
    )


def main() -> None:
    app()
