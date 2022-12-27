![Screenshot of Sodalite](https://git.zio.sh/sodaliterocks/lfs/media/branch/main/screenshots/screenshot.png?u=5)

<h1 align="center">
	Sodalite
</h1>

**Sodalite** is a ...

## 🎉 Quickstart

Know what you're in for? Here goes:

1. Install an rpm-ostree-based version of Fedora, such as [Fedora Silverblue](https://silverblue.fedoraproject.org/), or use an install you already have.
2. Fire up a terminal and issue these commands:
   - `sudo ostree remote add --if-not-exists sodalite https://ostree.sodalite.rocks --no-gpg-verify`
   - `sudo ostree pull sodalite:sodalite/stable/x86_64/desktop`
   - `sudo rpm-ostree rebase sodalite:sodalite/stable/x86_64/desktop`
3. Stick the kettle on and make yourself a cuppa. It'll take a while.
4. Reboot when prompted. Use it, enjoy it, make something cool with it, (try to) break it &mdash; [submit a ticket if you do](https://github.com/sodaliterocks/sodalite/issues/new)!

### Updating

_(todo)_

### Versioning

_(todo)_

---

<p align="center">
<b>See <a href="https://docs.sodalite.rocks)">Sodalite Docs</a> for more information</b> &mdash; the README beyond this is intended mostly for developers.
</p>

## 🤔 Status

_(todo)_

## 🏗️ Building

### 1. Prerequisites

- [Fedora Linux](https://getfedora.org/) (or other Fedora-based/compatible distros)
- [rpm-ostree](https://coreos.github.io/rpm-ostree/)
	- On most Fedora-based distros, this can be installed with `dnf install rpm-ostree`
- Bash
- [Git LFS](https://git-lfs.com/)
	- As well as including pretty wallpapers, the LFS also includes vital binaries that Sodalite needs to work properly, so don't miss installing this!
	- Unsure if you have LFS support? Just type `git lfs`.
- A cuppa _(optional)_ &mdash; this can take a while

### 2. Getting

```sh
git clone https://github.com/sodaliterocks/sodalite.git
cd sodalite
git submodule sync
git submodule update --init --recursive
```

### 3. Building

...

### 4. Using

...

## 🤝 Acknowledgements

* [Fabio Valentini ("decathorpe")](https://decathorpe.com/), for providing the extra packages for elementary on Fedora via the [elementary-staging Copr repository](https://copr.fedorainfracloud.org/coprs/decathorpe/elementary-staging/).
* [Jorge O. Castro](https://github.com/castrojo), for including Sodalite in [awesome-immutable](https://github.com/castrojo/awesome-immutable).
* [Timothée Ravier](https://tim.siosm.fr), for their extensive guidance to the community concerning Fedora Silverblue.
* ["Topfi"](https://github.com/ACertainTopfi), for their various contributions.
* The [elementary team](https://elementary.io/team), for building lovely stuff.
* The contributors to [workstation-ostree-config](https://pagure.io/workstation-ostree-config), for a solid ground to work from.
* The amazing photographers/artists of the included wallpapers &mdash; [Adrien Olichon](https://unsplash.com/@adrienolichon), [Austin Neill](https://unsplash.com/@arstyy), [Cody Fitzgerald](https://unsplash.com/@cfitz), [Dustin Humes](https://unsplash.com/@dustinhumes_photography), [Jack B.](https://unsplash.com/@nervum), [Jeremy Gerritsen](https://unsplash.com/@jeremygerritsen), [Karsten Würth](https://unsplash.com/@karsten_wuerth), [Max Okhrimenko](https://unsplash.com/@maxokhrimenko), [Nathan Dumlao](https://unsplash.com/@nate_dumlao), [Ryan Stone](https://unsplash.com/@rstone_design), [Smaran Alva](https://unsplash.com/@smal), [Willian Daigneault](https://unsplash.com/@williamdaigneault), and [Zara Walker](https://unsplash.com/@mojoblogs).
* The [Sodalite mineral](https://en.wikipedia.org/wiki/Sodalite), for the name. [It's a mineral, not a rock, Jesus](https://www.youtube.com/watch?v=r1yYJBzf1VQ)!
* The [Omicron variant of SARS-CoV-2](https://en.wikipedia.org/wiki/SARS-CoV-2_Omicron_variant), for giving [Ducky](https://github.com/electriduck) the initial free time to make this thing.

## 👀 See Also

* **[📄 Code of Conduct](CODE_OF_CONDUCT.MD)** &mdash; Contributor Covenant CoC
* **[📄 Contributing](CONTRIBUTING.MD)**
* **[🔗 Docs](https://docs.sodalite.rocks)**
* **[📄 License](LICENSE)** &mdash; MIT, &copy; 2022 Sodalite contributors

---

<p align="center">
This README was entirely overhauled on 28-Dec-2022, and removed a lot of fluff that was no longer needed, but if you're looking for the previous version see <a href="https://github.com/sodaliterocks/sodalite/blob/d482f66c7dfe300f02d0cc045bbe22a0720e6858/README.md">README.md@d482f66</a>.
</p>

---

## Scratch junk. Don't merge. Ducks are cute.

   - Updates will be received automatically from _Software_ (which runs in the background and sends desktop notifications), or you can update with `sudo rpm-ostree upgrade`.
   - Providing you stay on the `stable` branch (the "`stable`" in "`sodalite/stable/x86_64/desktop`"), you do not need to manually intervene to update to the next base version of Fedora.
     - **This is currently partially untrue as there will not be a 37-based version of Sodalite** &mdash; see [#44](https://github.com/sodaliterocks/sodalite/issues/44).
     - Versioning (which can be seen in **System Settings ➔ About**) is encoded as `<base>-<year>.<release>[.<update>]`, where:
       - `<base>` Base version of **Fedora**.
       - `<year>` Year of release using just two digits (i.e. 2023 becomes 23).
       - `<release>` Incremental release version; for additions, changes, and removals. Resets when a new year occurs, but does **not** reset on a new base version of Fedora.
       - `<release>` _(optional)_ Incremental update version that occurs when the server rebuilds the exact same release version to update packages.
   - Unlike most other rpm-ostree distros, a migration tool will be ran on each boot to correct a few things from previous installs, such as rectify various Flatpak apps (removing pre-installed GNOME apps and installing Pantheon apps), as well as clear up things from the previous install. The first one will take a while and you'll likely see a progress window on first login: don't worry, it will try its best to not cause murder and mayhem.
5. 
