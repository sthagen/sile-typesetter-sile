#[cfg(feature = "manpage")]
use clap_mangen::Man;
#[cfg(any(feature = "static", feature = "completions"))]
use std::path::Path;
use std::{collections, env};
use vergen_gix::{CargoBuilder, Emitter, GixBuilder, RustcBuilder};
#[cfg(feature = "completions")]
use {
    clap::CommandFactory,
    clap_complete::generator::generate_to,
    clap_complete::shells::{Bash, Elvish, Fish, PowerShell, Zsh},
    std::fs,
};

#[cfg(feature = "completions")]
include!("../src/cli.rs");

fn main() {
    if let Ok(val) = env::var("AUTOTOOLS_DEPENDENCIES") {
        for dependency in val.split(' ') {
            println!("cargo:rerun-if-changed={dependency}");
        }
    }
    let mut builder = Emitter::default();
    builder
        .add_instructions(&CargoBuilder::all_cargo().unwrap())
        .unwrap();
    // If passed a version from automake, use that instead of vergen's formatting
    if let Ok(val) = env::var("VERSION_FROM_AUTOTOOLS") {
        println!("cargo:rustc-env=VERGEN_GIT_DESCRIBE={val}");
        builder
            .add_instructions(&RustcBuilder::all_rustc().unwrap())
            .unwrap();
    } else {
        builder
            .add_instructions(&GixBuilder::all_git().unwrap())
            .unwrap();
    };
    builder.emit().unwrap();
    pass_on_configure_details();
    #[cfg(feature = "manpage")]
    generate_manpage();
    #[cfg(feature = "completions")]
    generate_shell_completions();
    #[cfg(feature = "static")]
    {
        let dir = env::var("CARGO_MANIFEST_DIR").unwrap();
        println!(
            "cargo:rustc-link-search=native={}",
            Path::new(&dir).join("justenough").join(".libs").display()
        );
        println!(
            "cargo:rustc-link-search=native={}",
            Path::new(&dir).join("libtexpdf").join(".libs").display()
        );
        println!("cargo:rustc-link-arg=-l:fontmetrics.a");
        println!("cargo:rustc-link-arg=-l:justenoughfontconfig.a");
        println!("cargo:rustc-link-arg=-l:justenoughharfbuzz.a");
        println!("cargo:rustc-link-arg=-l:justenoughicu.a");
        println!("cargo:rustc-link-arg=-l:justenoughlibtexpdf.a");
        println!("cargo:rustc-link-arg=-l:svg.a");
        println!("cargo:rustc-link-arg=-l:libtexpdf.a");

        // These are automatically linked by Cargo, but sadly *previous* to our links above
        println!("cargo:rustc-link-arg=-lharfbuzz"); // needed by justenoughharfbuzz
        #[cfg(feature = "variations")]
        println!("cargo:rustc-link-arg=-lharfbuzz-subset"); // needed by justenoughharfbuzz
        println!("cargo:rustc-link-arg=-lfontconfig"); // needed by justenoughfontconfig
        println!("cargo:rustc-link-arg=-licui18n"); // needed by justenoughicu
        println!("cargo:rustc-link-arg=-licuuc"); // needed by justenoughicu
        println!("cargo:rustc-link-arg=-lm"); // needed by svg
        println!("cargo:rustc-link-arg=-lz"); // needed by libtexpdf
        println!("cargo:rustc-link-arg=-lpng"); // needed by libtexpdf
    }
}

/// Generate man page
#[cfg(feature = "manpage")]
fn generate_manpage() {
    let out_dir = match env::var_os("OUT_DIR") {
        None => return,
        Some(out_dir) => out_dir,
    };
    let manpage_dir = Path::new(&out_dir);
    fs::create_dir_all(manpage_dir).expect("Unable to create directory for generated manpages");
    let app = Cli::command();
    let bin_name: &str = app
        .get_bin_name()
        .expect("Could not retrieve bin-name from generated Clap app");
    let app = Cli::command();
    let man = Man::new(app);
    let mut buffer: Vec<u8> = Default::default();
    man.render(&mut buffer)
        .expect("Unable to render man page to UTF-8 string");
    fs::write(manpage_dir.join(format!("{bin_name}.1")), buffer)
        .expect("Unable to write manepage to file");
}

/// Generate shell completion files from CLI interface
#[cfg(feature = "completions")]
fn generate_shell_completions() {
    let out_dir = match env::var_os("OUT_DIR") {
        None => return,
        Some(out_dir) => out_dir,
    };
    let completions_dir = Path::new(&out_dir).join("completions");
    fs::create_dir_all(&completions_dir)
        .expect("Could not create directory in which to place completions");
    let app = Cli::command();
    let bin_name: &str = app
        .get_bin_name()
        .expect("Could not retrieve bin-name from generated Clap app");
    let mut app = Cli::command();
    #[cfg(feature = "bash")]
    generate_to(Bash, &mut app, bin_name, &completions_dir)
        .expect("Unable to generate bash completions");
    #[cfg(feature = "elvish")]
    generate_to(Elvish, &mut app, bin_name, &completions_dir)
        .expect("Unable to generate elvish completions");
    #[cfg(feature = "fish")]
    generate_to(Fish, &mut app, bin_name, &completions_dir)
        .expect("Unable to generate fish completions");
    #[cfg(feature = "powershell")]
    generate_to(PowerShell, &mut app, bin_name, &completions_dir)
        .expect("Unable to generate powershell completions");
    #[cfg(feature = "zsh")]
    generate_to(Zsh, &mut app, bin_name, &completions_dir)
        .expect("Unable to generate zsh completions");
}

/// Pass through some variables set by autoconf/automake about where we're installed to cargo for
/// use in finding resources at runtime
fn pass_on_configure_details() {
    let mut autoconf_vars = collections::HashMap::new();
    autoconf_vars.insert("CONFIGURE_PREFIX", String::from("./"));
    autoconf_vars.insert("CONFIGURE_BINDIR", String::from("./"));
    autoconf_vars.insert("CONFIGURE_DATADIR", String::from("./"));
    for (var, default) in autoconf_vars {
        let val = env::var(var).unwrap_or(default);
        println!("cargo:rustc-env={var}={val}");
    }
}
