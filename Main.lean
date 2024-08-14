import DocGen4
import Lean
import Cli

open DocGen4 Lean Cli

def getTopLevelModules (p : Parsed) : IO (List String) :=  do
  let topLevelModules := p.variableArgsAs! String |>.toList
  if topLevelModules.length == 0 then
    throw <| IO.userError "No topLevelModules provided."
  return topLevelModules

def runHeaderDataCmd (_p : Parsed) : IO UInt32 := do
  headerDataOutput
  return 0

def runSingleCmd (p : Parsed) : IO UInt32 := do
  let relevantModules := #[p.positionalArg! "module" |>.as! String |> String.toName]
  let sourceUri := p.positionalArg! "sourceUri" |>.as! String
  let (doc, hierarchy) ← load <| .loadAllLimitAnalysis relevantModules
  let baseConfig ← getSimpleBaseContext hierarchy
  htmlOutputResults baseConfig doc (some sourceUri)
  return 0

def runIndexCmd (_p : Parsed) : IO UInt32 := do
  let hierarchy ← Hierarchy.fromDirectory Output.basePath
  let baseConfig ← getSimpleBaseContext hierarchy
  htmlOutputIndex baseConfig
  return 0

def runGenCoreCmd (_p : Parsed) : IO UInt32 := do
  let (doc, hierarchy) ← loadCore
  let baseConfig ← getSimpleBaseContext hierarchy
  htmlOutputResults baseConfig doc none
  return 0

def runDocGenCmd (_p : Parsed) : IO UInt32 := do
  IO.println "You most likely want to use me via Lake now, check my README on Github on how to:"
  IO.println "https://github.com/leanprover/doc-gen4"
  return 0

def runBibPrepassCmd (p : Parsed) : IO UInt32 := do
  if p.hasFlag "none" then
    IO.println "INFO: reference page disabled"
    disableBibFile
  else
    match p.variableArgsAs! String with
    | #[source] =>
      let contents ← IO.FS.readFile source
      if p.hasFlag "json" then
        IO.println "INFO: 'references.json' will be copied to the output path; there will be no 'references.bib'"
        preprocessBibJson contents
      else
        preprocessBibFile contents Bibtex.process
    | _ => throw <| IO.userError "there should be exactly one source file"
  return 0

def singleCmd := `[Cli|
  single VIA runSingleCmd;
  "Only generate the documentation for the module it was given, might contain broken links unless all documentation is generated."

  ARGS:
    module : String; "The module to generate the HTML for. Does not have to be part of topLevelModules."
    sourceUri : String; "The sourceUri as computed by the Lake facet"
]

def indexCmd := `[Cli|
  index VIA runIndexCmd;
  "Index the documentation that has been generated by single."
]

def genCoreCmd := `[Cli|
  genCore VIA runGenCoreCmd;
  "Generate documentation for the core Lean modules: Init, Lean, Lake and Std since they are not Lake projects"
]

def bibPrepassCmd := `[Cli|
  bibPrepass VIA runBibPrepassCmd;
  "Run the bibliography prepass: copy the bibliography file to output directory. By default it assumes the input is '.bib'."

  FLAGS:
    n, none; "Disable bibliography in this project."
    j, json; "The input file is '.json' which contains an array of objects with 4 fields: 'citekey', 'tag', 'html' and 'plaintext'."

  ARGS:
    ...source : String; "The bibliography file. We only support one file for input. Should be '.bib' or '.json' according to flags."
]

def headerDataCmd := `[Cli|
  headerData VIA runHeaderDataCmd;
  "Produce `header-data.bmp`, this allows embedding of doc-gen declarations into other pages and more."
]

def docGenCmd : Cmd := `[Cli|
  "doc-gen4" VIA runDocGenCmd; ["0.1.0"]
  "A documentation generator for Lean 4."

  SUBCOMMANDS:
    singleCmd;
    indexCmd;
    genCoreCmd;
    bibPrepassCmd;
    headerDataCmd
]

def main (args : List String) : IO UInt32 :=
  docGenCmd.validate args
