# OMICstudio 0.4.0

Multi-omics suite. OMICstudio grew out of
[scStudio](https://github.com/Tianqi-Ma/scStudio) (single-cell only), which is
still maintained standalone; shared changes are mirrored between the two.

## Added
- **Omics landing page.** Five cards — single-cell RNA-seq, bulk RNA-seq, WES,
  spatial transcriptomics, multi-omics integration — each with a themed canvas
  animation on hover. Picking one routes into that pipeline; a "← Omics" link in
  the top bar returns to the chooser.
- **Per-omics step registries** (`R/steps.R`) as the single source of truth for
  the navigator and the workspace. Bulk / WES / spatial / integration show their
  planned steps through a placeholder module, each card naming its own step.
- **Clinical & survival step** (single-cell step 18), backed by a new
  omics-agnostic `R/fct_survival.R`: Kaplan-Meier curves drawn in ggplot2, the
  log-rank test, median survival per arm, and univariable Cox regression.
  Stratify by a clinical column or by **per-sample cell-type composition**
  (median / tertile / log-rank-optimal cutpoint). The maths uses `survival`,
  which ships with R, so nothing needs to be compiled. The normalised cohort is
  written to the shared hub (`rv$clinical`) for the other pipelines to reuse.
- **Import overview.** The Import step now previews the raw data before any
  filtering: per-cell QC violins, top-20 expressed genes, a counts-vs-genes
  scatter, the cell metadata table and a slice of the counts matrix. Species is
  detected from gene-name casing so mouse data no longer reads 0% mitochondrial.
- **Shared export menu** in the top bar, available on every step: the object
  (.rds), cell metadata (.csv), counts matrix (.rds) and embeddings (.csv).
- **Bundled pbmc3k.** The real 2,700-cell 10x PBMC dataset ships inside the
  package, so the recommended demo loads instantly and offline — no download and
  no SeuratData.

## Fixed
- The Import overview called `scstudio_theme()`, a name that does not exist in
  this package after the rename, so the whole overview panel rendered as an
  error message. Two tests now guard this: every module's outputs are forced to
  evaluate, and every function is checked for calls to names that do not resolve.
- The bundled launchers (`inst/launch.bat`, `inst/launch.command`) still invoked
  `scStudio::run_app()` and could never have worked.
- `DESCRIPTION` declared `bslib (>= 0.5.0)` while the UI uses
  `input_dark_mode()` (bslib 0.6.0) and `input_task_button()` (bslib 0.7.0);
  installing against an older bslib produced an app that crashed on startup.
  Now `bslib (>= 0.7.0)`.
- Interactive plots asked `ggplotly()` for a `text` tooltip that no layer
  provides, so hovering showed an empty box; and a multi-gene FeaturePlot (a
  patchwork) was handed to `ggplotly()`, which cannot render it. Interactivity is
  now used only where it works, and shows the real values.
- Static assets 404'd without `addResourcePath()`; plot failures surfaced as an
  empty "Plot error:" or an opaque `[object Object]`.
- Visualize / Report / Export never marked themselves complete, so the step
  navigator could not reach the end of the pipeline.
- The Export step could error on its own filename when the format input had not
  been initialised.
- Missing styles for the sidebar's empty-state and dataset readout; the Google
  font is now optional rather than a hard requirement for an offline app.

## Known limitations
- **Not validated end-to-end.** The single-cell pipeline is fully wired and
  statically validated (parse, UI build, output evaluation, tests, install) but
  has not been run against a live Seurat/scop install with real data; some scop
  argument names still need checking.
- Bulk, WES, spatial and integration are roadmap only.
- The "optimal" survival cutpoint is exploratory: chosen to maximise separation,
  so its p-value is optimistic.
- `.h5ad` export is best-effort (SeuratDisk); `.rds` is primary.

---

# scStudio 0.3.0 (inherited history)

- **scop as the engine.** Plotting (`CellDimPlot`, `GroupHeatmap`,
  `DynamicHeatmap`, `VolcanoPlot`, ...) and compute (`Standard_SCP`,
  `Integration_SCP`, `RunDEtest`, `RunEnrichment`, `RunGSEA`, `RunSlingshot`,
  Monocle2/3, PAGA, Palantir, WOT, scVelo, dynamic features) behind wrappers that
  degrade to a readable message when scop is absent.
- Eight new steps: enrichment/GSEA, trajectory, RNA velocity, dynamic features,
  cell cycle & signatures, cell communication (LIANA/CellChat), malignancy/CNV
  (CopyKAT), and the narrated report. Twenty steps across seven phases.
- Mascarade cluster outlining on the embedding and visualization steps.

# scStudio 0.2.0

- Dark theme by default with a light toggle; grouped left step navigator with
  per-step status; `input_task_button()` so a running step is visibly running;
  plot-first layout (narrow control rail, large canvas, collapsed explainer).
- Single-language interface (English or 中文, never both) via `data-en`/`data-zh`
  attributes swapped client-side — no server round-trip.
- Startup animation: scattered cells coalescing into UMAP-like clusters.

# scStudio 0.1.0

- First scaffold: localhost-first Shiny app launched with `run_app()`, twelve
  analysis modules following a uniform pattern, MAD-based QC, scDblFinder,
  Harmony, Leiden, UMAP/t-SNE, SingleR/Azimuth, a reproducibility log exportable
  as an R script, a Docker image, and a bilingual README.
