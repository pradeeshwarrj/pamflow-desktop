# Third-party notices

pamflow Desktop itself is MIT-licensed (see `LICENSE`). The installer also
contains software written by others. Each part keeps its own license; this list
says what is inside and under which license it is distributed. It is a summary:
the packages in the installed analysis engine carry their own license files, and
the projects' own pages are the authority.

## Inside the installer

| Part | What it is used for | License |
|---|---|---|
| [pamflow](https://github.com/pradeeshwarrj/pamflow) | The analysis (R package) | MIT |
| [R](https://www.r-project.org/) and its packages | Runs pamflow | GPL-2 or GPL-3 (R); each package has its own |
| [Python](https://www.python.org/) | Runs BirdNET | Python Software Foundation License |
| [birdnet](https://github.com/birdnet-team/birdnet) | Runs the BirdNET detector | MIT |
| [TensorFlow](https://www.tensorflow.org/) | Runs BirdNET models | Apache-2.0 |
| [FFmpeg](https://ffmpeg.org/) | Reads and converts audio | LGPL-2.1 or GPL, depending on the build |
| [pandoc](https://pandoc.org/) | Writes HTML reports | GPL-2.0 or later |
| [Tauri](https://tauri.app/) | The app window | MIT or Apache-2.0 |
| [Svelte](https://svelte.dev/) and the interface's other packages | The interface | MIT and similar; see `pnpm-lock.yaml` |
| [pixi](https://pixi.sh/) and pixi-pack | Build and unpack the analysis engine | BSD-3-Clause |

R, pandoc and FFmpeg are separate programs that pamflow Desktop starts; it does
not link to them. Their source code is available from the projects above.

## Not in the installer

| Part | License |
|---|---|
| BirdNET's global model files, downloaded by the user from [Zenodo](https://zenodo.org/records/15050749) when they ask for it | CC BY-NC-SA 4.0 (non-commercial) |
| Classifiers the user trains or supplies | The user's own terms |

If you use BirdNET, please cite Kahl et al. (2021), *BirdNET: A deep learning
solution for avian diversity monitoring*, Ecological Informatics 61, 101236.
