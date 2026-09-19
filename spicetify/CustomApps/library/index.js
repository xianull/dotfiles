var library = (() => {
  var __create = Object.create;
  var __defProp = Object.defineProperty;
  var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
  var __getOwnPropNames = Object.getOwnPropertyNames;
  var __getProtoOf = Object.getPrototypeOf;
  var __hasOwnProp = Object.prototype.hasOwnProperty;
  var __commonJS = (cb, mod) => function __require() {
    return mod || (0, cb[__getOwnPropNames(cb)[0]])((mod = { exports: {} }).exports, mod), mod.exports;
  };
  var __export = (target, all) => {
    for (var name in all)
      __defProp(target, name, { get: all[name], enumerable: true });
  };
  var __copyProps = (to, from, except, desc) => {
    if (from && typeof from === "object" || typeof from === "function") {
      for (let key of __getOwnPropNames(from))
        if (!__hasOwnProp.call(to, key) && key !== except)
          __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
    }
    return to;
  };
  var __toESM = (mod, isNodeMode, target) => (target = mod != null ? __create(__getProtoOf(mod)) : {}, __copyProps(
    isNodeMode || !mod || !mod.__esModule ? __defProp(target, "default", { value: mod, enumerable: true }) : target,
    mod
  ));
  var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);

  // external-global-plugin:react
  var require_react = __commonJS({
    "external-global-plugin:react"(exports, module) {
      module.exports = Spicetify.React;
    }
  });

  // external-global-plugin:react-dom
  var require_react_dom = __commonJS({
    "external-global-plugin:react-dom"(exports, module) {
      module.exports = Spicetify.ReactDOM;
    }
  });

  // ../../../AppData/Local/Temp/spicetify-creator/index.jsx
  var spicetify_creator_exports = {};
  __export(spicetify_creator_exports, {
    default: () => render
  });

  // src/app.tsx
  var import_react28 = __toESM(require_react());

  // src/pages/albums.tsx
  var import_react21 = __toESM(require_react());

  // src/components/searchbar.tsx
  var import_react = __toESM(require_react());
  var searchIconPath = `<path d="M7 1.75a5.25 5.25 0 1 0 0 10.5 5.25 5.25 0 0 0 0-10.5M.25 7a6.75 6.75 0 1 1 12.096 4.12l3.184 3.185a.75.75 0 1 1-1.06 1.06L11.304 12.2A6.75 6.75 0 0 1 .25 7"></path>`;
  var SearchBar = (props) => {
    const { setSearch, placeholder } = props;
    const { IconComponent } = Spicetify.ReactComponent;
    const handleChange = (e) => {
      setSearch(e.target.value);
    };
    const searchIcon = /* @__PURE__ */ import_react.default.createElement(IconComponent, {
      className: "x-filterBox-searchIcon",
      size: "small",
      viewBox: "0 0 16 16",
      dangerouslySetInnerHTML: {
        __html: searchIconPath
      }
    });
    return /* @__PURE__ */ import_react.default.createElement("div", {
      className: "x-filterBox-filterInputContainer x-filterBox-expandedOrHasFilter",
      role: "search"
    }, /* @__PURE__ */ import_react.default.createElement("input", {
      type: "text",
      className: "x-filterBox-filterInput",
      role: "searchbox",
      maxLength: 80,
      autoCorrect: "off",
      autoCapitalize: "off",
      spellCheck: "false",
      placeholder: `Search ${placeholder}`,
      "aria-hidden": "false",
      onChange: handleChange
    }), /* @__PURE__ */ import_react.default.createElement("div", {
      className: "x-filterBox-overlay"
    }, /* @__PURE__ */ import_react.default.createElement("span", {
      className: "x-filterBox-searchIconContainer"
    }, searchIcon)), /* @__PURE__ */ import_react.default.createElement("button", {
      className: "x-filterBox-expandButton",
      "aria-hidden": "false",
      "aria-label": "Search Playlists",
      type: "button"
    }, searchIcon));
  };
  var searchbar_default = SearchBar;

  // ../shared/components/settings_button.tsx
  var import_react2 = __toESM(require_react());
  function SettingsIcon() {
    return /* @__PURE__ */ import_react2.default.createElement(Spicetify.ReactComponent.IconComponent, {
      semanticColor: "textSubdued",
      dangerouslySetInnerHTML: {
        __html: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M24 13.616v-3.232c-1.651-.587-2.694-.752-3.219-2.019v-.001c-.527-1.271.1-2.134.847-3.707l-2.285-2.285c-1.561.742-2.433 1.375-3.707.847h-.001c-1.269-.526-1.435-1.576-2.019-3.219h-3.232c-.582 1.635-.749 2.692-2.019 3.219h-.001c-1.271.528-2.132-.098-3.707-.847l-2.285 2.285c.745 1.568 1.375 2.434.847 3.707-.527 1.271-1.584 1.438-3.219 2.02v3.232c1.632.58 2.692.749 3.219 2.019.53 1.282-.114 2.166-.847 3.707l2.285 2.286c1.562-.743 2.434-1.375 3.707-.847h.001c1.27.526 1.436 1.579 2.019 3.219h3.232c.582-1.636.75-2.69 2.027-3.222h.001c1.262-.524 2.12.101 3.698.851l2.285-2.286c-.744-1.563-1.375-2.433-.848-3.706.527-1.271 1.588-1.44 3.221-2.021zm-12 2.384c-2.209 0-4-1.791-4-4s1.791-4 4-4 4 1.791 4 4-1.791 4-4 4z"/></svg>'
      },
      iconSize: 16
    });
  }
  function SettingsButton(props) {
    const { TooltipWrapper, ButtonTertiary } = Spicetify.ReactComponent;
    const { configWrapper } = props;
    return /* @__PURE__ */ import_react2.default.createElement(TooltipWrapper, {
      label: "Settings",
      renderInline: true,
      placement: "top"
    }, /* @__PURE__ */ import_react2.default.createElement(ButtonTertiary, {
      buttonSize: "sm",
      onClick: configWrapper.launchModal,
      "aria-label": "Settings",
      iconOnly: SettingsIcon
    }));
  }
  var settings_button_default = SettingsButton;

  // ../shared/dropdown/useDropdownMenu.tsx
  var import_react4 = __toESM(require_react());

  // ../shared/dropdown/dropdown.tsx
  var import_react3 = __toESM(require_react());
  function CheckIcon() {
    return /* @__PURE__ */ import_react3.default.createElement(Spicetify.ReactComponent.IconComponent, {
      iconSize: 16,
      semanticColor: "textBase",
      dangerouslySetInnerHTML: {
        __html: '<svg xmlns="http://www.w3.org/2000/svg"><path d="M15.53 2.47a.75.75 0 0 1 0 1.06L4.907 14.153.47 9.716a.75.75 0 0 1 1.06-1.06l3.377 3.376L14.47 2.47a.75.75 0 0 1 1.06 0z"/></svg>'
      }
    });
  }
  var MenuItem = (props) => {
    const { ReactComponent } = Spicetify;
    const { option, isActive, switchCallback } = props;
    const activeStyle = {
      backgroundColor: "rgba(var(--spice-rgb-selected-row),.1)"
    };
    return /* @__PURE__ */ import_react3.default.createElement(ReactComponent.MenuItem, {
      trigger: "click",
      onClick: () => switchCallback(option),
      "data-checked": isActive,
      trailingIcon: isActive ? /* @__PURE__ */ import_react3.default.createElement(CheckIcon, null) : void 0,
      style: isActive ? activeStyle : void 0
    }, option.name);
  };
  var DropdownMenu = (props) => {
    const { ContextMenu, Menu, TextComponent } = Spicetify.ReactComponent;
    const { options, activeOption, switchCallback } = props;
    const optionItems = options.map((option) => {
      return /* @__PURE__ */ import_react3.default.createElement(MenuItem, {
        option,
        isActive: option === activeOption,
        switchCallback
      });
    });
    const MenuWrapper = (props2) => {
      return /* @__PURE__ */ import_react3.default.createElement(Menu, {
        ...props2
      }, optionItems);
    };
    return /* @__PURE__ */ import_react3.default.createElement(ContextMenu, {
      menu: /* @__PURE__ */ import_react3.default.createElement(MenuWrapper, null),
      trigger: "click"
    }, /* @__PURE__ */ import_react3.default.createElement("button", {
      className: "x-sortBox-sortDropdown",
      type: "button",
      role: "combobox",
      "aria-expanded": "false"
    }, /* @__PURE__ */ import_react3.default.createElement(TextComponent, {
      variant: "mesto",
      semanticColor: "textSubdued"
    }, activeOption.name), /* @__PURE__ */ import_react3.default.createElement("svg", {
      role: "img",
      height: "16",
      width: "16",
      "aria-hidden": "true",
      className: "Svg-img-16 Svg-img-16-icon Svg-img-icon Svg-img-icon-small",
      viewBox: "0 0 16 16",
      "data-encore-id": "icon"
    }, /* @__PURE__ */ import_react3.default.createElement("path", {
      d: "m14 6-6 6-6-6h12z"
    }))));
  };
  var dropdown_default = DropdownMenu;

  // ../shared/dropdown/useDropdownMenu.tsx
  var useDropdownMenu = (options, storageVariable) => {
    const initialOptionID = storageVariable && Spicetify.LocalStorage.get(`${storageVariable}:active-option`);
    const initialOption = initialOptionID && options.find((e) => e.id === initialOptionID);
    const [activeOption, setActiveOption] = (0, import_react4.useState)(initialOption || options[0]);
    const [availableOptions, setAvailableOptions] = (0, import_react4.useState)(options);
    const dropdown = /* @__PURE__ */ import_react4.default.createElement(dropdown_default, {
      options: availableOptions,
      activeOption,
      switchCallback: (option) => {
        setActiveOption(option);
        if (storageVariable)
          Spicetify.LocalStorage.set(`${storageVariable}:active-option`, option.id);
      }
    });
    return [dropdown, activeOption, setActiveOption, setAvailableOptions];
  };
  var useDropdownMenu_default = useDropdownMenu;

  // ../shared/components/page_container.tsx
  var import_react5 = __toESM(require_react());
  var PageContainer = (props) => {
    const { rhs, lhs, children } = props;
    const { TextComponent } = Spicetify.ReactComponent;
    function parseNodes(nodes) {
      return nodes.map(
        (node) => typeof node === "string" ? /* @__PURE__ */ import_react5.default.createElement(TextComponent, {
          children: node,
          as: "h1",
          variant: "canon",
          semanticColor: "textBase"
        }) : node
      );
    }
    return /* @__PURE__ */ import_react5.default.createElement("section", {
      className: "contentSpacing"
    }, /* @__PURE__ */ import_react5.default.createElement("div", {
      className: "page-header"
    }, /* @__PURE__ */ import_react5.default.createElement("div", {
      className: "header-left"
    }, parseNodes(lhs)), /* @__PURE__ */ import_react5.default.createElement("div", {
      className: "header-right"
    }, rhs)), /* @__PURE__ */ import_react5.default.createElement("div", {
      className: "page-content"
    }, children));
  };
  var page_container_default = PageContainer;

  // src/components/collection_menu.tsx
  var import_react8 = __toESM(require_react());

  // src/components/text_input_dialog.tsx
  var import_react6 = __toESM(require_react());
  var TextInputDialog = (props) => {
    const { def, placeholder, onSave } = props;
    const [value, setValue] = import_react6.default.useState(def || "");
    const onSubmit = (e) => {
      e.preventDefault();
      Spicetify.PopupModal.hide();
      onSave(value);
    };
    return /* @__PURE__ */ import_react6.default.createElement(import_react6.default.Fragment, null, /* @__PURE__ */ import_react6.default.createElement("form", {
      className: "text-input-form",
      onSubmit
    }, /* @__PURE__ */ import_react6.default.createElement("label", {
      className: "text-input-wrapper"
    }, /* @__PURE__ */ import_react6.default.createElement("input", {
      className: "text-input",
      type: "text",
      value,
      placeholder,
      onChange: (e) => setValue(e.target.value)
    })), /* @__PURE__ */ import_react6.default.createElement("button", {
      type: "submit",
      "data-encore-id": "buttonPrimary",
      className: "Button-sc-qlcn5g-0 Button-small-buttonPrimary"
    }, /* @__PURE__ */ import_react6.default.createElement("span", {
      className: "ButtonInner-sc-14ud5tc-0 ButtonInner-small encore-bright-accent-set"
    }, "Save"))));
  };
  var text_input_dialog_default = TextInputDialog;

  // src/components/leading_icon.tsx
  var import_react7 = __toESM(require_react());
  var LeadingIcon = ({ path }) => {
    return /* @__PURE__ */ import_react7.default.createElement(Spicetify.ReactComponent.IconComponent, {
      semanticColor: "textSubdued",
      dangerouslySetInnerHTML: {
        __html: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16">${path}</svg>`
      },
      iconSize: 16
    });
  };
  var leading_icon_default = LeadingIcon;

  // src/components/collection_menu.tsx
  var editIconPath = '<path d="M11.838.714a2.438 2.438 0 0 1 3.448 3.448l-9.841 9.841c-.358.358-.79.633-1.267.806l-3.173 1.146a.75.75 0 0 1-.96-.96l1.146-3.173c.173-.476.448-.909.806-1.267l9.84-9.84zm2.387 1.06a.938.938 0 0 0-1.327 0l-9.84 9.842a1.953 1.953 0 0 0-.456.716L2 14.002l1.669-.604a1.95 1.95 0 0 0 .716-.455l9.841-9.841a.938.938 0 0 0 0-1.327z"></path>';
  var deleteIconPath = '<path d="M8 1.5a6.5 6.5 0 1 0 0 13 6.5 6.5 0 0 0 0-13zM0 8a8 8 0 1 1 16 0A8 8 0 0 1 0 8z"></path><path d="M12 8.75H4v-1.5h8v1.5z"></path>';
  var addIconPath = '<path d="M15.25 8a.75.75 0 0 1-.75.75H8.75v5.75a.75.75 0 0 1-1.5 0V8.75H1.5a.75.75 0 0 1 0-1.5h5.75V1.5a.75.75 0 0 1 1.5 0v5.75h5.75a.75.75 0 0 1 .75.75z"></path>';
  var CollectionMenu = ({ id }) => {
    const { Menu, MenuItem: MenuItem2 } = Spicetify.ReactComponent;
    const deleteCollection = () => {
      CollectionsWrapper.deleteCollection(id);
    };
    const deleteCollectionAndAlbums = () => {
      CollectionsWrapper.deleteCollectionAndAlbums(id);
    };
    const renameCollection = () => {
      const name = CollectionsWrapper.getCollection(id)?.name;
      const rename = (newName) => {
        CollectionsWrapper.renameCollection(id, newName);
      };
      Spicetify.PopupModal.display({
        title: "Rename Collection",
        content: /* @__PURE__ */ import_react8.default.createElement(text_input_dialog_default, {
          def: name,
          placeholder: "Collection Name",
          onSave: rename
        })
      });
    };
    const collection = CollectionsWrapper.getCollection(id);
    const image = collection?.image;
    const synced = collection?.syncedPlaylistUri;
    const setCollectionImage = () => {
      const setImg = (imgUrl) => {
        CollectionsWrapper.setCollectionImage(id, imgUrl);
      };
      Spicetify.PopupModal.display({
        title: "Set Collection Image",
        content: /* @__PURE__ */ import_react8.default.createElement(text_input_dialog_default, {
          def: image,
          placeholder: "Image URL",
          onSave: setImg
        })
      });
    };
    const removeImage = () => {
      CollectionsWrapper.removeCollectionImage(id);
    };
    const convertToPlaylist = () => {
      CollectionsWrapper.convertToPlaylist(id);
    };
    const unsyncPlaylist = () => {
      CollectionsWrapper.unsyncCollection(id);
    };
    return /* @__PURE__ */ import_react8.default.createElement(Menu, null, /* @__PURE__ */ import_react8.default.createElement(MenuItem2, {
      leadingIcon: /* @__PURE__ */ import_react8.default.createElement(leading_icon_default, {
        path: editIconPath
      }),
      onClick: renameCollection
    }, "Rename"), /* @__PURE__ */ import_react8.default.createElement(MenuItem2, {
      leadingIcon: /* @__PURE__ */ import_react8.default.createElement(leading_icon_default, {
        path: deleteIconPath
      }),
      onClick: deleteCollection
    }, "Delete (Only Collection)"), /* @__PURE__ */ import_react8.default.createElement(MenuItem2, {
      leadingIcon: /* @__PURE__ */ import_react8.default.createElement(leading_icon_default, {
        path: deleteIconPath
      }),
      onClick: deleteCollectionAndAlbums
    }, "Delete (Collection and Albums)"), synced ? /* @__PURE__ */ import_react8.default.createElement(MenuItem2, {
      leadingIcon: /* @__PURE__ */ import_react8.default.createElement(leading_icon_default, {
        path: deleteIconPath
      }),
      onClick: unsyncPlaylist
    }, "Unsync from Playlist") : /* @__PURE__ */ import_react8.default.createElement(MenuItem2, {
      leadingIcon: /* @__PURE__ */ import_react8.default.createElement(leading_icon_default, {
        path: addIconPath
      }),
      onClick: convertToPlaylist
    }, "Sync to Playlist"), /* @__PURE__ */ import_react8.default.createElement(MenuItem2, {
      leadingIcon: /* @__PURE__ */ import_react8.default.createElement(leading_icon_default, {
        path: editIconPath
      }),
      onClick: setCollectionImage
    }, "Set Collection Image"), image && /* @__PURE__ */ import_react8.default.createElement(MenuItem2, {
      leadingIcon: /* @__PURE__ */ import_react8.default.createElement(leading_icon_default, {
        path: deleteIconPath
      }),
      onClick: removeImage
    }, "Remove Collection Image"));
  };
  var collection_menu_default = CollectionMenu;

  // src/components/folder_menu.tsx
  var import_react9 = __toESM(require_react());
  var editIconPath2 = '<path d="M11.838.714a2.438 2.438 0 0 1 3.448 3.448l-9.841 9.841c-.358.358-.79.633-1.267.806l-3.173 1.146a.75.75 0 0 1-.96-.96l1.146-3.173c.173-.476.448-.909.806-1.267l9.84-9.84zm2.387 1.06a.938.938 0 0 0-1.327 0l-9.84 9.842a1.953 1.953 0 0 0-.456.716L2 14.002l1.669-.604a1.95 1.95 0 0 0 .716-.455l9.841-9.841a.938.938 0 0 0 0-1.327z"></path>';
  var deleteIconPath2 = '<path d="M8 1.5a6.5 6.5 0 1 0 0 13 6.5 6.5 0 0 0 0-13zM0 8a8 8 0 1 1 16 0A8 8 0 0 1 0 8z"></path><path d="M12 8.75H4v-1.5h8v1.5z"></path>';
  var FolderMenu = ({ uri }) => {
    const { MenuItem: MenuItem2, Menu } = Spicetify.ReactComponent;
    const image = FolderImageWrapper.getFolderImage(uri);
    const setImage = () => {
      const setNewImage = (newUrl) => {
        FolderImageWrapper.setFolderImage({ uri, url: newUrl });
      };
      Spicetify.PopupModal.display({
        title: "Set Folder Image",
        content: /* @__PURE__ */ import_react9.default.createElement(text_input_dialog_default, {
          def: image,
          onSave: setNewImage,
          placeholder: "Image URL"
        })
      });
    };
    const removeImage = () => {
      FolderImageWrapper.removeFolderImage(uri);
    };
    return /* @__PURE__ */ import_react9.default.createElement(Menu, null, /* @__PURE__ */ import_react9.default.createElement(MenuItem2, {
      leadingIcon: /* @__PURE__ */ import_react9.default.createElement(leading_icon_default, {
        path: editIconPath2
      }),
      onClick: setImage
    }, "Set Folder Image"), image && /* @__PURE__ */ import_react9.default.createElement(MenuItem2, {
      leadingIcon: /* @__PURE__ */ import_react9.default.createElement(leading_icon_default, {
        path: deleteIconPath2
      }),
      onClick: removeImage
    }, "Remove Folder Image"));
  };
  var folder_menu_default = FolderMenu;

  // ../shared/components/spotify_card.tsx
  var import_react12 = __toESM(require_react());

  // ../shared/components/folder_fallback.tsx
  var import_react10 = __toESM(require_react());
  var FolderSVG = (e) => {
    return /* @__PURE__ */ import_react10.default.createElement(Spicetify.ReactComponent.IconComponent, {
      semanticColor: "textSubdued",
      viewBox: "0 0 24 24",
      size: "xxlarge",
      dangerouslySetInnerHTML: {
        __html: '<path d="M1 4a2 2 0 0 1 2-2h5.155a3 3 0 0 1 2.598 1.5l.866 1.5H21a2 2 0 0 1 2 2v13a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V4zm7.155 0H3v16h18V7H10.464L9.021 4.5a1 1 0 0 0-.866-.5z"/>'
      },
      ...e
    });
  };
  var folder_fallback_default = FolderSVG;

  // src/components/local_album_menu.tsx
  var import_react11 = __toESM(require_react());
  var LocalAlbumMenu = ({ id }) => {
    const { Menu, MenuItem: MenuItem2 } = Spicetify.ReactComponent;
    return /* @__PURE__ */ import_react11.default.createElement(Menu, null);
  };
  var local_album_menu_default = LocalAlbumMenu;

  // ../shared/components/spotify_card.tsx
  function SpotifyCard(props) {
    const { Cards, TextComponent, ArtistMenu, AlbumMenu, PodcastShowMenu, PlaylistMenu, ContextMenu } = Spicetify.ReactComponent;
    const { FeatureCard: Card, CardImage } = Cards;
    const { History } = Spicetify.Platform;
    const { type, header, uri, imageUrl, subheader, artistUri, badge, provider } = props;
    const Menu = () => {
      switch (type) {
        case "artist":
          return /* @__PURE__ */ import_react12.default.createElement(ArtistMenu, {
            uri
          });
        case "album":
          return /* @__PURE__ */ import_react12.default.createElement(AlbumMenu, {
            uri,
            artistUri,
            canRemove: true
          });
        case "playlist":
          return /* @__PURE__ */ import_react12.default.createElement(PlaylistMenu, {
            uri
          });
        case "show":
          return /* @__PURE__ */ import_react12.default.createElement(PodcastShowMenu, {
            uri
          });
        case "collection":
          return /* @__PURE__ */ import_react12.default.createElement(collection_menu_default, {
            id: uri
          });
        case "folder":
          return /* @__PURE__ */ import_react12.default.createElement(folder_menu_default, {
            uri
          });
        case "localalbum":
          return /* @__PURE__ */ import_react12.default.createElement(local_album_menu_default, {
            id: uri
          });
        default:
          return /* @__PURE__ */ import_react12.default.createElement(import_react12.default.Fragment, null);
      }
    };
    const lastfmProps = provider === "lastfm" ? {
      onClick: () => window.open(uri, "_blank"),
      isPlayable: false,
      delegateNavigation: true
    } : {};
    const folderProps = type === "folder" ? {
      delegateNavigation: true,
      onClick: () => {
        Spicetify.Platform.History.replace(`/library/Playlists/${uri}`);
        Spicetify.LocalStorage.set("library:active-link", `Playlists/${uri}`);
      }
    } : {};
    const collectionProps = type === "collection" ? {
      delegateNavigation: true,
      onClick: () => {
        Spicetify.Platform.History.replace(`/library/Collections/${uri}`);
        Spicetify.LocalStorage.set("library:active-link", `Collections/${uri}`);
      }
    } : {};
    const localAlbumProps = type === "localalbum" ? {
      delegateNavigation: true,
      onClick: () => {
        History.push({ pathname: "better-local-files/album", state: { uri } });
      }
    } : {};
    return /* @__PURE__ */ import_react12.default.createElement(ContextMenu, {
      menu: Menu(),
      trigger: "right-click"
    }, /* @__PURE__ */ import_react12.default.createElement("div", {
      style: { position: "relative" }
    }, /* @__PURE__ */ import_react12.default.createElement(Card, {
      featureIdentifier: type,
      headerText: header,
      renderCardImage: () => /* @__PURE__ */ import_react12.default.createElement(CardImage, {
        images: [
          {
            height: 640,
            url: imageUrl,
            width: 640
          }
        ],
        isCircular: type === "artist",
        FallbackComponent: type === "folder" || type === "collection" ? folder_fallback_default : void 0
      }),
      renderSubHeaderContent: () => /* @__PURE__ */ import_react12.default.createElement(TextComponent, {
        as: "div",
        variant: "mesto",
        semanticColor: "textSubdued"
      }, subheader),
      uri,
      ...lastfmProps,
      ...folderProps,
      ...collectionProps,
      ...localAlbumProps
    }), badge && /* @__PURE__ */ import_react12.default.createElement("div", {
      className: "badge"
    }, badge)));
  }
  var spotify_card_default = SpotifyCard;

  // src/components/load_more_card.tsx
  var import_react13 = __toESM(require_react());
  var LoadMoreCard = (props) => {
    const { callback } = props;
    return /* @__PURE__ */ import_react13.default.createElement("div", {
      onClick: callback,
      className: "load-more-card main-card-card"
    }, /* @__PURE__ */ import_react13.default.createElement("div", {
      className: "svg-placeholder"
    }, /* @__PURE__ */ import_react13.default.createElement("svg", {
      viewBox: "0 8 24 8",
      xmlns: "http://www.w3.org/2000/svg"
    }, /* @__PURE__ */ import_react13.default.createElement("circle", {
      cx: "17.5",
      cy: "12",
      r: "1.5"
    }), /* @__PURE__ */ import_react13.default.createElement("circle", {
      cx: "12",
      cy: "12",
      r: "1.5"
    }), /* @__PURE__ */ import_react13.default.createElement("circle", {
      cx: "6.5",
      cy: "12",
      r: "1.5"
    }))), /* @__PURE__ */ import_react13.default.createElement(Spicetify.ReactComponent.TextComponent, {
      as: "div",
      variant: "violaBold",
      semanticColor: "textBase",
      weight: "bold"
    }, "Load More"));
  };
  var load_more_card_default = LoadMoreCard;

  // src/components/add_button.tsx
  var import_react14 = __toESM(require_react());
  function AddIcon() {
    return /* @__PURE__ */ import_react14.default.createElement(Spicetify.ReactComponent.IconComponent, {
      semanticColor: "textSubdued",
      dangerouslySetInnerHTML: {
        __html: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16"><path d="M15.25 8a.75.75 0 0 1-.75.75H8.75v5.75a.75.75 0 0 1-1.5 0V8.75H1.5a.75.75 0 0 1 0-1.5h5.75V1.5a.75.75 0 0 1 1.5 0v5.75h5.75a.75.75 0 0 1 .75.75z"></path></svg>'
      },
      iconSize: 16
    });
  }
  function AddButton(props) {
    const { ReactComponent } = Spicetify;
    const { TooltipWrapper, ButtonTertiary, ContextMenu } = ReactComponent;
    const { Menu } = props;
    return /* @__PURE__ */ import_react14.default.createElement(TooltipWrapper, {
      label: "Add",
      placement: "top"
    }, /* @__PURE__ */ import_react14.default.createElement("span", null, /* @__PURE__ */ import_react14.default.createElement(ContextMenu, {
      trigger: "click",
      menu: Menu
    }, /* @__PURE__ */ import_react14.default.createElement(ButtonTertiary, {
      buttonSize: "sm",
      "aria-label": "Add",
      iconOnly: AddIcon
    }))));
  }
  var add_button_default = AddButton;

  // ../shared/status/useStatus.tsx
  var import_react16 = __toESM(require_react());

  // ../shared/status/status.tsx
  var import_react15 = __toESM(require_react());
  var ErrorIcon = () => {
    return /* @__PURE__ */ import_react15.default.createElement("svg", {
      "data-encore-id": "icon",
      role: "img",
      "aria-hidden": "true",
      viewBox: "0 0 24 24",
      className: "status-icon"
    }, /* @__PURE__ */ import_react15.default.createElement("path", {
      d: "M11 18v-2h2v2h-2zm0-4V6h2v8h-2z"
    }), /* @__PURE__ */ import_react15.default.createElement("path", {
      d: "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM1 12C1 5.925 5.925 1 12 1s11 4.925 11 11-4.925 11-11 11S1 18.075 1 12z"
    }));
  };
  var LibraryIcon = () => {
    return /* @__PURE__ */ import_react15.default.createElement("svg", {
      role: "img",
      height: "46",
      width: "46",
      "aria-hidden": "true",
      viewBox: "0 0 24 24",
      "data-encore-id": "icon",
      className: "status-icon"
    }, /* @__PURE__ */ import_react15.default.createElement("path", {
      d: "M14.5 2.134a1 1 0 0 1 1 0l6 3.464a1 1 0 0 1 .5.866V21a1 1 0 0 1-1 1h-6a1 1 0 0 1-1-1V3a1 1 0 0 1 .5-.866zM16 4.732V20h4V7.041l-4-2.309zM3 22a1 1 0 0 1-1-1V3a1 1 0 0 1 2 0v18a1 1 0 0 1-1 1zm6 0a1 1 0 0 1-1-1V3a1 1 0 0 1 2 0v18a1 1 0 0 1-1 1z"
    }));
  };
  var Status = (props) => {
    const [isVisible, setIsVisible] = import_react15.default.useState(false);
    import_react15.default.useEffect(() => {
      const to = setTimeout(() => {
        setIsVisible(true);
      }, 500);
      return () => clearTimeout(to);
    }, []);
    return isVisible ? /* @__PURE__ */ import_react15.default.createElement(import_react15.default.Fragment, null, /* @__PURE__ */ import_react15.default.createElement("div", {
      className: "loadingWrapper"
    }, props.icon === "error" ? /* @__PURE__ */ import_react15.default.createElement(ErrorIcon, null) : /* @__PURE__ */ import_react15.default.createElement(LibraryIcon, null), /* @__PURE__ */ import_react15.default.createElement("h1", null, props.heading), /* @__PURE__ */ import_react15.default.createElement("h3", null, props.subheading))) : /* @__PURE__ */ import_react15.default.createElement(import_react15.default.Fragment, null);
  };
  var status_default = Status;

  // ../shared/status/useStatus.tsx
  var useStatus = (status, error) => {
    if (status === "pending") {
      return /* @__PURE__ */ import_react16.default.createElement(status_default, {
        icon: "library",
        heading: "Loading",
        subheading: "Please wait, this may take a moment"
      });
    }
    if (status === "error") {
      return /* @__PURE__ */ import_react16.default.createElement(status_default, {
        icon: "error",
        heading: "Error",
        subheading: error?.message || "An unknown error occurred"
      });
    }
    return null;
  };
  var useStatus_default = useStatus;

  // ../shared/types/react_query.ts
  var ReactQuery = Spicetify.ReactQuery;
  var useQuery = (...args) => ReactQuery.useQuery(...args);
  var useInfiniteQuery = (...args) => ReactQuery.useInfiniteQuery(...args);

  // src/components/pin_icon.tsx
  var import_react17 = __toESM(require_react());
  var PinIcon = () => /* @__PURE__ */ import_react17.default.createElement(Spicetify.ReactComponent.IconComponent, {
    semanticColor: "textBase",
    viewBox: "0 0 16 16",
    iconSize: 12
  }, /* @__PURE__ */ import_react17.default.createElement("path", {
    d: "M8.822.797a2.72 2.72 0 0 1 3.847 0l2.534 2.533a2.72 2.72 0 0 1 0 3.848l-3.678 3.678-1.337 4.988-4.486-4.486L1.28 15.78a.75.75 0 0 1-1.06-1.06l4.422-4.422L.156 5.812l4.987-1.337L8.822.797z"
  }));
  var pin_icon_default = PinIcon;

  // ../shared/dropdown/useSortDropdownMenu.tsx
  var import_react20 = __toESM(require_react());

  // src/components/icons/arrows.tsx
  var import_react18 = __toESM(require_react());
  var UpArrow = () => {
    const { IconComponent } = Spicetify.ReactComponent;
    return /* @__PURE__ */ import_react18.default.createElement(IconComponent, {
      semanticColor: "textSubdued",
      dangerouslySetInnerHTML: {
        __html: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16"><path d="M.998 8.81A.749.749 0 0 1 .47 7.53L7.99 0l7.522 7.53a.75.75 0 1 1-1.06 1.06L8.74 2.87v12.38a.75.75 0 1 1-1.498 0V2.87L1.528 8.59a.751.751 0 0 1-.53.22z"></path></svg>'
      },
      iconSize: 16
    });
  };
  var DownArrow = () => {
    const { IconComponent } = Spicetify.ReactComponent;
    return /* @__PURE__ */ import_react18.default.createElement(IconComponent, {
      semanticColor: "textSubdued",
      dangerouslySetInnerHTML: {
        __html: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16"><path d="M.998 7.19A.749.749 0 0 0 .47 8.47L7.99 16l7.522-7.53a.75.75 0 1 0-1.06-1.06L8.74 13.13V.75a.75.75 0 1 0-1.498 0v12.38L1.528 7.41a.749.749 0 0 0-.53-.22z"></path></svg>'
      },
      iconSize: 16
    });
  };

  // ../shared/dropdown/sort_dropdown.tsx
  var import_react19 = __toESM(require_react());
  var SortMenuItem = (props) => {
    const { ReactComponent } = Spicetify;
    const { option, isActive, isReversed, switchCallback } = props;
    const activeStyle = {
      backgroundColor: "rgba(var(--spice-rgb-selected-row),.1)"
    };
    return /* @__PURE__ */ import_react19.default.createElement(ReactComponent.MenuItem, {
      trigger: "click",
      onClick: () => switchCallback(option),
      "data-checked": isActive,
      trailingIcon: isActive ? isReversed ? /* @__PURE__ */ import_react19.default.createElement(DownArrow, null) : /* @__PURE__ */ import_react19.default.createElement(UpArrow, null) : void 0,
      style: isActive ? activeStyle : void 0
    }, option.name);
  };
  var SortDropdownMenu = (props) => {
    const { ContextMenu, Menu, TextComponent } = Spicetify.ReactComponent;
    const { options, activeOption, isReversed, switchCallback } = props;
    const optionItems = options.map((option) => {
      return /* @__PURE__ */ import_react19.default.createElement(SortMenuItem, {
        option,
        isActive: option === activeOption,
        isReversed,
        switchCallback
      });
    });
    const MenuWrapper = (props2) => {
      return /* @__PURE__ */ import_react19.default.createElement(Menu, {
        ...props2
      }, optionItems);
    };
    return /* @__PURE__ */ import_react19.default.createElement(ContextMenu, {
      menu: /* @__PURE__ */ import_react19.default.createElement(MenuWrapper, null),
      trigger: "click"
    }, /* @__PURE__ */ import_react19.default.createElement("button", {
      className: "x-sortBox-sortDropdown",
      type: "button",
      role: "combobox",
      "aria-expanded": "false"
    }, /* @__PURE__ */ import_react19.default.createElement(TextComponent, {
      variant: "mesto",
      semanticColor: "textSubdued"
    }, activeOption.name, isReversed ? /* @__PURE__ */ import_react19.default.createElement(DownArrow, null) : /* @__PURE__ */ import_react19.default.createElement(UpArrow, null)), /* @__PURE__ */ import_react19.default.createElement("svg", {
      role: "img",
      height: "16",
      width: "16",
      "aria-hidden": "true",
      className: "Svg-img-16 Svg-img-16-icon Svg-img-icon Svg-img-icon-small",
      viewBox: "0 0 16 16",
      "data-encore-id": "icon"
    }, /* @__PURE__ */ import_react19.default.createElement("path", {
      d: "m14 6-6 6-6-6h12z"
    }))));
  };
  var sort_dropdown_default = SortDropdownMenu;

  // ../shared/dropdown/useSortDropdownMenu.tsx
  var useSortDropdownMenu = (options, storageVariable) => {
    const initialOptionID = storageVariable && Spicetify.LocalStorage.get(`${storageVariable}:active-option`);
    const initialOption = initialOptionID && options.find((e) => e.id === initialOptionID);
    const [activeOption, setActiveOption] = (0, import_react20.useState)(initialOption || options[0]);
    const [isReversed, setIsReversed] = (0, import_react20.useState)(false);
    const [availableOptions, setAvailableOptions] = (0, import_react20.useState)(options);
    const dropdown = /* @__PURE__ */ import_react20.default.createElement(sort_dropdown_default, {
      options: availableOptions,
      isReversed,
      activeOption,
      switchCallback: (option) => {
        setIsReversed((prev) => option.id === activeOption.id ? !prev : prev);
        setActiveOption(option);
        if (storageVariable)
          Spicetify.LocalStorage.set(`${storageVariable}:active-option`, option.id);
      }
    });
    return [dropdown, activeOption, isReversed, setActiveOption, setAvailableOptions];
  };
  var useSortDropdownMenu_default = useSortDropdownMenu;

  // src/utils/collection_sort.ts
  function collectionSort(order, reverse) {
    const sortBy = (a, b) => {
      if (a.pinned || b.pinned)
        return 0;
      switch (order) {
        case "0":
          return a.name.replace(/^the\s+/i, "").localeCompare(b.name.replace(/^the\s+/i, ""));
        case "1":
          return new Date(b.addedAt).getTime() - new Date(a.addedAt).getTime();
        case "2":
          if (a.type === "collection")
            return -1;
          if (b.type === "collection")
            return 1;
          return a.artists[0].name.replace(/^the\s+/i, "").localeCompare(b.artists[0].name.replace(/^the\s+/i, ""));
        case "6":
          return new Date(b.lastPlayedAt).getTime() - new Date(a.lastPlayedAt).getTime();
        default:
          return 0;
      }
    };
    return reverse ? (a, b) => sortBy(b, a) : sortBy;
  }
  var collection_sort_default = collectionSort;

  // src/pages/albums.tsx
  var AddMenu = () => {
    const { MenuItem: MenuItem2, Menu } = Spicetify.ReactComponent;
    const { SVGIcons } = Spicetify;
    const addAlbum = () => {
      const onSave = (value) => {
        Spicetify.Platform.LibraryAPI.add({ uris: [value] });
      };
      Spicetify.PopupModal.display({
        title: "Add Album",
        content: /* @__PURE__ */ import_react21.default.createElement(text_input_dialog_default, {
          def: "",
          placeholder: "Album URI",
          onSave
        })
      });
    };
    return /* @__PURE__ */ import_react21.default.createElement(Menu, null, /* @__PURE__ */ import_react21.default.createElement(MenuItem2, {
      onClick: addAlbum,
      leadingIcon: /* @__PURE__ */ import_react21.default.createElement(leading_icon_default, {
        path: SVGIcons.album
      })
    }, "Add Album"));
  };
  var limit = 200;
  var sortOptions = [
    { id: "0", name: "Name" },
    { id: "1", name: "Date Added" },
    { id: "2", name: "Artist Name" },
    { id: "6", name: "Recents" }
  ];
  var filterOptions = [
    { id: "0", name: "All" },
    { id: "1", name: "Albums" },
    { id: "2", name: "Local Albums" }
  ];
  var AlbumsPage = ({ configWrapper }) => {
    const [sortDropdown, sortOption, isReversed] = useSortDropdownMenu_default(sortOptions, "library:albums");
    const [filterDropdown, filterOption] = useDropdownMenu_default(filterOptions);
    const [textFilter, setTextFilter] = import_react21.default.useState("");
    const fetchAlbums = async ({ pageParam }) => {
      const res = await Spicetify.Platform.LibraryAPI.getContents({
        filters: ["0"],
        sortOrder: sortOption.id,
        textFilter,
        sortDirection: isReversed ? "reverse" : void 0,
        offset: pageParam,
        limit
      });
      return res;
    };
    const fetchLocalAlbums = async () => {
      const localAlbums = await CollectionsWrapper.getLocalAlbums();
      let albums2 = localAlbums.values().toArray();
      if (textFilter) {
        const regex = new RegExp(`\\b${textFilter}`, "i");
        albums2 = albums2.filter((album) => {
          return regex.test(album.name) || album.artists.some((artist) => regex.test(artist.name));
        });
      }
      return albums2;
    };
    const { data, status, error, hasNextPage, fetchNextPage, refetch } = useInfiniteQuery({
      queryKey: ["library:albums", sortOption.id, isReversed, textFilter],
      queryFn: fetchAlbums,
      initialPageParam: 0,
      getNextPageParam: (lastPage) => {
        const current = lastPage.offset + limit;
        if (lastPage.totalLength > current)
          return current;
      }
    });
    const {
      data: localData,
      status: localStatus,
      error: localError
    } = useQuery({
      queryKey: ["library:localAlbums", textFilter],
      queryFn: fetchLocalAlbums,
      enabled: configWrapper.config.localAlbums
    });
    (0, import_react21.useEffect)(() => {
      const update = (e) => {
        if (e.data.list === "albums")
          refetch();
      };
      Spicetify.Platform.LibraryAPI.getEvents()._emitter.addListener("update", update, {});
      return () => {
        Spicetify.Platform.LibraryAPI.getEvents()._emitter.removeListener("update", update);
      };
    }, [refetch]);
    const Status2 = useStatus_default(status, error);
    const LocalStatus = configWrapper.config.localAlbums && useStatus_default(localStatus, localError);
    const EmptyStatus = useStatus_default("error", new Error("No albums found"));
    const props = {
      lhs: ["Albums"],
      rhs: [
        /* @__PURE__ */ import_react21.default.createElement(add_button_default, {
          Menu: /* @__PURE__ */ import_react21.default.createElement(AddMenu, null)
        }),
        filterDropdown,
        sortDropdown,
        /* @__PURE__ */ import_react21.default.createElement(searchbar_default, {
          setSearch: setTextFilter,
          placeholder: "Albums"
        }),
        /* @__PURE__ */ import_react21.default.createElement(settings_button_default, {
          configWrapper
        })
      ]
    };
    if (Status2)
      return /* @__PURE__ */ import_react21.default.createElement(page_container_default, {
        ...props
      }, Status2);
    if (LocalStatus)
      return /* @__PURE__ */ import_react21.default.createElement(page_container_default, {
        ...props
      }, LocalStatus);
    const contents = data;
    let albums = filterOption.id !== "2" ? contents.pages.flatMap((page) => page.items) : [];
    if (localData?.length && filterOption.id !== "1") {
      albums = albums.concat(localData).sort(collection_sort_default(sortOption.id, isReversed));
    }
    if (albums.length === 0)
      return /* @__PURE__ */ import_react21.default.createElement(page_container_default, {
        ...props
      }, EmptyStatus);
    const albumCards = albums.map((item) => {
      return /* @__PURE__ */ import_react21.default.createElement(spotify_card_default, {
        provider: "spotify",
        type: item.type || "localalbum",
        uri: item.uri,
        header: item.name,
        subheader: item.artists[0].name,
        imageUrl: item.images?.[0]?.url,
        artistUri: item.artists[0].uri,
        badge: item.pinned ? /* @__PURE__ */ import_react21.default.createElement(pin_icon_default, null) : void 0
      });
    });
    if (hasNextPage)
      albumCards.push(/* @__PURE__ */ import_react21.default.createElement(load_more_card_default, {
        callback: fetchNextPage
      }));
    return /* @__PURE__ */ import_react21.default.createElement(page_container_default, {
      ...props
    }, /* @__PURE__ */ import_react21.default.createElement("div", {
      className: "main-gridContainer-gridContainer grid"
    }, albumCards));
  };
  var albums_default = AlbumsPage;

  // src/pages/artists.tsx
  var import_react22 = __toESM(require_react());
  var AddMenu2 = () => {
    const { MenuItem: MenuItem2, Menu } = Spicetify.ReactComponent;
    const { SVGIcons } = Spicetify;
    const addAlbum = () => {
      const onSave = (value) => {
        Spicetify.Platform.LibraryAPI.add({ uris: [value] });
      };
      Spicetify.PopupModal.display({
        title: "Add Artist",
        content: /* @__PURE__ */ import_react22.default.createElement(text_input_dialog_default, {
          def: "",
          placeholder: "Artist URI",
          onSave
        })
      });
    };
    return /* @__PURE__ */ import_react22.default.createElement(Menu, null, /* @__PURE__ */ import_react22.default.createElement(MenuItem2, {
      onClick: addAlbum,
      leadingIcon: /* @__PURE__ */ import_react22.default.createElement(leading_icon_default, {
        path: SVGIcons.artist
      })
    }, "Add Artist"));
  };
  var limit2 = 200;
  var sortOptions2 = [
    { id: "0", name: "Name" },
    { id: "1", name: "Date Added" }
  ];
  var ArtistsPage = ({ configWrapper }) => {
    const [sortDropdown, sortOption, isReversed] = useSortDropdownMenu_default(sortOptions2, "library:artists");
    const [textFilter, setTextFilter] = import_react22.default.useState("");
    const fetchArtists = async ({ pageParam }) => {
      const res = await Spicetify.Platform.LibraryAPI.getContents({
        filters: ["1"],
        sortOrder: sortOption.id,
        textFilter,
        offset: pageParam,
        sortDirection: isReversed ? "reverse" : void 0,
        limit: limit2
      });
      if (!res.items?.length)
        throw new Error("No artists found");
      return res;
    };
    const { data, status, error, hasNextPage, fetchNextPage, refetch } = useInfiniteQuery({
      queryKey: ["library:artists", sortOption.id, isReversed, textFilter],
      queryFn: fetchArtists,
      initialPageParam: 0,
      getNextPageParam: (lastPage) => {
        const current = lastPage.offset + limit2;
        if (lastPage.totalLength > current)
          return current;
      }
    });
    (0, import_react22.useEffect)(() => {
      const update = (e) => {
        if (e.data.list === "artists")
          refetch();
      };
      Spicetify.Platform.LibraryAPI.getEvents()._emitter.addListener("update", update, {});
      return () => {
        Spicetify.Platform.LibraryAPI.getEvents()._emitter.removeListener("update", update);
      };
    }, [refetch]);
    const Status2 = useStatus_default(status, error);
    const props = {
      lhs: ["Artists"],
      rhs: [
        /* @__PURE__ */ import_react22.default.createElement(add_button_default, {
          Menu: /* @__PURE__ */ import_react22.default.createElement(AddMenu2, null)
        }),
        sortDropdown,
        /* @__PURE__ */ import_react22.default.createElement(searchbar_default, {
          setSearch: setTextFilter,
          placeholder: "Artists"
        }),
        /* @__PURE__ */ import_react22.default.createElement(settings_button_default, {
          configWrapper
        })
      ]
    };
    if (Status2)
      return /* @__PURE__ */ import_react22.default.createElement(page_container_default, {
        ...props
      }, Status2);
    const contents = data;
    const artists = contents.pages.flatMap((page) => page.items);
    const artistCards = artists.map((artist) => /* @__PURE__ */ import_react22.default.createElement(spotify_card_default, {
      provider: "spotify",
      type: "artist",
      uri: artist.uri,
      header: artist.name,
      subheader: "",
      imageUrl: artist.images?.at(0)?.url,
      badge: artist.pinned ? /* @__PURE__ */ import_react22.default.createElement(pin_icon_default, null) : void 0
    }));
    if (hasNextPage)
      artistCards.push(/* @__PURE__ */ import_react22.default.createElement(load_more_card_default, {
        callback: fetchNextPage
      }));
    return /* @__PURE__ */ import_react22.default.createElement(page_container_default, {
      ...props
    }, /* @__PURE__ */ import_react22.default.createElement("div", {
      className: "main-gridContainer-gridContainer grid"
    }, artistCards));
  };
  var artists_default = ArtistsPage;

  // src/pages/shows.tsx
  var import_react23 = __toESM(require_react());
  var AddMenu3 = () => {
    const { MenuItem: MenuItem2, Menu } = Spicetify.ReactComponent;
    const { SVGIcons } = Spicetify;
    const addAlbum = () => {
      const onSave = (value) => {
        Spicetify.Platform.LibraryAPI.add({ uris: [value] });
      };
      Spicetify.PopupModal.display({
        title: "Add Show",
        content: /* @__PURE__ */ import_react23.default.createElement(text_input_dialog_default, {
          def: "",
          placeholder: "Show URI",
          onSave
        })
      });
    };
    return /* @__PURE__ */ import_react23.default.createElement(Menu, null, /* @__PURE__ */ import_react23.default.createElement(MenuItem2, {
      onClick: addAlbum,
      leadingIcon: /* @__PURE__ */ import_react23.default.createElement(leading_icon_default, {
        path: SVGIcons.podcasts
      })
    }, "Add Show"));
  };
  var limit3 = 200;
  var sortOptions3 = [
    { id: "0", name: "Name" },
    { id: "1", name: "Date Added" }
  ];
  var ShowsPage = ({ configWrapper }) => {
    const [sortDropdown, sortOption, isReversed] = useSortDropdownMenu_default(sortOptions3, "library:shows");
    const [textFilter, setTextFilter] = import_react23.default.useState("");
    const fetchShows = async ({ pageParam }) => {
      const res = await Spicetify.Platform.LibraryAPI.getContents({
        filters: ["3"],
        sortOrder: sortOption.id,
        textFilter,
        sortDirection: isReversed ? "reverse" : void 0,
        offset: pageParam,
        limit: limit3
      });
      if (!res.items?.length)
        throw new Error("No shows found");
      return res;
    };
    const { data, status, error, hasNextPage, fetchNextPage, refetch } = useInfiniteQuery({
      queryKey: ["library:shows", sortOption.id, isReversed, textFilter],
      queryFn: fetchShows,
      initialPageParam: 0,
      getNextPageParam: (lastPage) => {
        const current = lastPage.offset + limit3;
        if (lastPage.totalLength > current)
          return current;
      }
    });
    (0, import_react23.useEffect)(() => {
      const update = (e) => {
        if (e.data.list === "shows")
          refetch();
      };
      Spicetify.Platform.LibraryAPI.getEvents()._emitter.addListener("update", update, {});
      return () => {
        Spicetify.Platform.LibraryAPI.getEvents()._emitter.removeListener("update", update);
      };
    }, [refetch]);
    const Status2 = useStatus_default(status, error);
    const props = {
      lhs: ["Shows"],
      rhs: [
        /* @__PURE__ */ import_react23.default.createElement(add_button_default, {
          Menu: /* @__PURE__ */ import_react23.default.createElement(AddMenu3, null)
        }),
        sortDropdown,
        /* @__PURE__ */ import_react23.default.createElement(searchbar_default, {
          setSearch: setTextFilter,
          placeholder: "Shows"
        }),
        /* @__PURE__ */ import_react23.default.createElement(settings_button_default, {
          configWrapper
        })
      ]
    };
    if (Status2)
      return /* @__PURE__ */ import_react23.default.createElement(page_container_default, {
        ...props
      }, Status2);
    const contents = data;
    const shows = contents.pages.flatMap((page) => page.items);
    const showCards = shows.map((show) => /* @__PURE__ */ import_react23.default.createElement(spotify_card_default, {
      provider: "spotify",
      type: "show",
      uri: show.uri,
      header: show.name,
      subheader: show.publisher,
      imageUrl: show.images?.[0]?.url,
      badge: show.pinned ? /* @__PURE__ */ import_react23.default.createElement(pin_icon_default, null) : void 0
    }));
    if (hasNextPage)
      showCards.push(/* @__PURE__ */ import_react23.default.createElement(load_more_card_default, {
        callback: fetchNextPage
      }));
    return /* @__PURE__ */ import_react23.default.createElement(page_container_default, {
      ...props
    }, /* @__PURE__ */ import_react23.default.createElement("div", {
      className: "main-gridContainer-gridContainer grid"
    }, showCards));
  };
  var shows_default = ShowsPage;

  // src/pages/playlists.tsx
  var import_react25 = __toESM(require_react());

  // src/components/back_button.tsx
  var import_react24 = __toESM(require_react());
  function BackIcon() {
    return /* @__PURE__ */ import_react24.default.createElement(Spicetify.ReactComponent.IconComponent, {
      semanticColor: "textSubdued",
      dangerouslySetInnerHTML: {
        __html: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M15.957 2.793a1 1 0 0 1 0 1.414L8.164 12l7.793 7.793a1 1 0 1 1-1.414 1.414L5.336 12l9.207-9.207a1 1 0 0 1 1.414 0z"></path></svg>'
      },
      iconSize: 16
    });
  }
  function BackButton({ url }) {
    const { TooltipWrapper, ButtonTertiary } = Spicetify.ReactComponent;
    function navigate() {
      Spicetify.Platform.History.replace(`/library/${url}`);
      Spicetify.LocalStorage.set("library:active-link", url);
    }
    return /* @__PURE__ */ import_react24.default.createElement(TooltipWrapper, {
      label: "Back",
      placement: "top"
    }, /* @__PURE__ */ import_react24.default.createElement("span", null, /* @__PURE__ */ import_react24.default.createElement(ButtonTertiary, {
      buttonSize: "sm",
      "aria-label": "Back",
      iconOnly: BackIcon,
      onClick: navigate
    })));
  }
  var back_button_default = BackButton;

  // src/pages/playlists.tsx
  var AddMenu4 = ({ folder }) => {
    const { MenuItem: MenuItem2, Menu } = Spicetify.ReactComponent;
    const { RootlistAPI } = Spicetify.Platform;
    const { SVGIcons } = Spicetify;
    const insertLocation = folder ? { uri: folder } : "start";
    const createFolder = () => {
      const onSave = (value) => {
        RootlistAPI.createFolder(value || "New Folder", { after: insertLocation });
      };
      Spicetify.PopupModal.display({
        title: "Create Folder",
        content: /* @__PURE__ */ import_react25.default.createElement(text_input_dialog_default, {
          def: "New Folder",
          placeholder: "Folder Name",
          onSave
        })
      });
    };
    const createPlaylist = () => {
      const onSave = (value) => {
        RootlistAPI.createPlaylist(value || "New Playlist", { after: insertLocation });
      };
      Spicetify.PopupModal.display({
        title: "Create Playlist",
        content: /* @__PURE__ */ import_react25.default.createElement(text_input_dialog_default, {
          def: "New Playlist",
          placeholder: "Playlist Name",
          onSave
        })
      });
    };
    return /* @__PURE__ */ import_react25.default.createElement(Menu, null, /* @__PURE__ */ import_react25.default.createElement(MenuItem2, {
      onClick: createFolder,
      leadingIcon: /* @__PURE__ */ import_react25.default.createElement(leading_icon_default, {
        path: SVGIcons["playlist-folder"]
      })
    }, "Create Folder"), /* @__PURE__ */ import_react25.default.createElement(MenuItem2, {
      onClick: createPlaylist,
      leadingIcon: /* @__PURE__ */ import_react25.default.createElement(leading_icon_default, {
        path: SVGIcons.playlist
      })
    }, "Create Playlist"));
  };
  var limit4 = 200;
  var dropdownOptions = [
    { id: "0", name: "Name" },
    { id: "1", name: "Date Added" },
    { id: "2", name: "Creator" },
    { id: "4", name: "Custom Order" },
    { id: "6", name: "Recents" }
  ];
  var filterOptions2 = [
    { id: "all", name: "All" },
    { id: "100", name: "Downloaded" },
    { id: "102", name: "By You" },
    { id: "103", name: "By Spotify" }
  ];
  var flattenOptions = [
    { id: "false", name: "Unflattened" },
    { id: "true", name: "Flattened" }
  ];
  var PlaylistsPage = ({ configWrapper }) => {
    const [sortDropdown, sortOption, isReversed] = useSortDropdownMenu_default(dropdownOptions, "library:playlists-sort");
    const [filterDropdown, filterOption] = useDropdownMenu_default(filterOptions2);
    const [flattenDropdown, flattenOption] = useDropdownMenu_default(flattenOptions);
    const [textFilter, setTextFilter] = import_react25.default.useState("");
    const [images, setImages] = import_react25.default.useState({ ...FolderImageWrapper.getFolderImages() });
    const folder = Spicetify.Platform.History.location.pathname.split("/")[3];
    const fetchRootlist = async ({ pageParam }) => {
      const filters = filterOption.id === "all" ? ["2"] : ["2", filterOption.id];
      const res = await Spicetify.Platform.LibraryAPI.getContents({
        filters,
        sortOrder: sortOption.id,
        sortDirection: isReversed ? "reverse" : void 0,
        folderUri: folder,
        textFilter,
        offset: pageParam,
        includeLikedSongs: configWrapper.config.includeLikedSongs,
        includeLocalFiles: configWrapper.config.includeLocalFiles,
        limit: limit4,
        flattenTree: JSON.parse(flattenOption.id)
      });
      if (!res.items?.length)
        throw new Error("No playlists found");
      return res;
    };
    const { data, status, error, hasNextPage, fetchNextPage, refetch } = useInfiniteQuery({
      queryKey: ["library:playlists", sortOption.id, isReversed, filterOption.id, flattenOption.id, textFilter, folder],
      queryFn: fetchRootlist,
      initialPageParam: 0,
      getNextPageParam: (lastPage) => {
        const current = lastPage.offset + limit4;
        if (lastPage.totalLength > current)
          return current;
      },
      retry: false
    });
    (0, import_react25.useEffect)(() => {
      const update = (e) => refetch();
      const updateImages = (e) => "detail" in e && setImages({ ...e.detail });
      FolderImageWrapper.addEventListener("update", updateImages);
      Spicetify.Platform.RootlistAPI.getEvents()._emitter.addListener("update", update, {});
      return () => {
        FolderImageWrapper.removeEventListener("update", updateImages);
        Spicetify.Platform.RootlistAPI.getEvents()._emitter.removeListener("update", update);
      };
    }, [refetch]);
    const Status2 = useStatus_default(status, error);
    const props = {
      lhs: [
        folder ? /* @__PURE__ */ import_react25.default.createElement(back_button_default, {
          url: `Playlists/${data?.pages[0].parentFolderUri}`
        }) : null,
        data?.pages[0].openedFolderName || "Playlists"
      ],
      rhs: [
        /* @__PURE__ */ import_react25.default.createElement(add_button_default, {
          Menu: /* @__PURE__ */ import_react25.default.createElement(AddMenu4, {
            folder
          })
        }),
        sortDropdown,
        filterDropdown,
        flattenDropdown,
        /* @__PURE__ */ import_react25.default.createElement(searchbar_default, {
          setSearch: setTextFilter,
          placeholder: "Playlists"
        }),
        /* @__PURE__ */ import_react25.default.createElement(settings_button_default, {
          configWrapper
        })
      ]
    };
    if (Status2)
      return /* @__PURE__ */ import_react25.default.createElement(page_container_default, {
        ...props
      }, Status2);
    const contents = data;
    const items = contents.pages.flatMap((page) => page.items);
    const rootlistCards = items.map((item) => /* @__PURE__ */ import_react25.default.createElement(spotify_card_default, {
      provider: "spotify",
      type: item.type,
      uri: item.uri !== "spotify:local-files" ? item.uri : "spotify:collection:local-files",
      header: item.name,
      subheader: item.type === "playlist" ? item.owner.name : item.type === "folder" ? `${item.numberOfPlaylists} Playlists${item.numberOfFolders ? ` \u2022 ${item.numberOfFolders} Folders` : ""}` : "System Playlist",
      imageUrl: item.images?.[0]?.url || images[item.uri],
      badge: item.pinned ? /* @__PURE__ */ import_react25.default.createElement(pin_icon_default, null) : void 0
    }));
    if (hasNextPage)
      rootlistCards.push(/* @__PURE__ */ import_react25.default.createElement(load_more_card_default, {
        callback: fetchNextPage
      }));
    return /* @__PURE__ */ import_react25.default.createElement(page_container_default, {
      ...props
    }, /* @__PURE__ */ import_react25.default.createElement("div", {
      className: "main-gridContainer-gridContainer grid"
    }, rootlistCards));
  };
  var playlists_default = PlaylistsPage;

  // package.json
  var version = "1.1.1";

  // src/pages/collections.tsx
  var import_react26 = __toESM(require_react());
  var AddMenu5 = ({ collection }) => {
    const { MenuItem: MenuItem2, Menu } = Spicetify.ReactComponent;
    const { RootlistAPI } = Spicetify.Platform;
    const { SVGIcons } = Spicetify;
    const createCollection = () => {
      const onSave = (value) => {
        CollectionsWrapper.createCollection(value || "New Collection", collection);
      };
      Spicetify.PopupModal.display({
        title: "Create Collection",
        content: /* @__PURE__ */ import_react26.default.createElement(text_input_dialog_default, {
          def: "New Collection",
          placeholder: "Collection Name",
          onSave
        })
      });
    };
    const createDiscogCollection = () => {
      const onSave = (value) => {
        CollectionsWrapper.createCollectionFromDiscog(value);
      };
      Spicetify.PopupModal.display({
        title: "Create Discog Collection",
        content: /* @__PURE__ */ import_react26.default.createElement(text_input_dialog_default, {
          def: "",
          placeholder: "Artist URI",
          onSave
        })
      });
    };
    const addAlbum = () => {
      if (!collection)
        return;
      const onSave = (value) => {
        CollectionsWrapper.addAlbumToCollection(collection, value);
      };
      Spicetify.PopupModal.display({
        title: "Add Album",
        content: /* @__PURE__ */ import_react26.default.createElement(text_input_dialog_default, {
          def: "",
          placeholder: "Album URI",
          onSave
        })
      });
    };
    return /* @__PURE__ */ import_react26.default.createElement(Menu, null, /* @__PURE__ */ import_react26.default.createElement(MenuItem2, {
      onClick: createCollection,
      leadingIcon: /* @__PURE__ */ import_react26.default.createElement(leading_icon_default, {
        path: SVGIcons["playlist-folder"]
      })
    }, "Create Collection"), /* @__PURE__ */ import_react26.default.createElement(MenuItem2, {
      onClick: createDiscogCollection,
      leadingIcon: /* @__PURE__ */ import_react26.default.createElement(leading_icon_default, {
        path: SVGIcons.artist
      })
    }, "Create Discog Collection"), collection && /* @__PURE__ */ import_react26.default.createElement(MenuItem2, {
      onClick: addAlbum,
      leadingIcon: /* @__PURE__ */ import_react26.default.createElement(leading_icon_default, {
        path: SVGIcons.album
      })
    }, "Add Album"));
  };
  var limit5 = 200;
  var sortOptions4 = [
    { id: "0", name: "Name" },
    { id: "1", name: "Date Added" },
    { id: "2", name: "Artist Name" },
    { id: "6", name: "Recents" }
  ];
  var CollectionsPage = ({ configWrapper }) => {
    const [sortDropdown, sortOption, isReversed] = useSortDropdownMenu_default(sortOptions4, "library:collections");
    const [textFilter, setTextFilter] = import_react26.default.useState("");
    const collection = Spicetify.Platform.History.location.pathname.split("/")[3];
    const fetchRootlist = async ({ pageParam }) => {
      const res = await CollectionsWrapper.getContents({
        collectionUri: collection,
        textFilter,
        offset: pageParam,
        sortOrder: sortOption.id,
        sortDirection: isReversed ? "reverse" : void 0,
        limit: limit5
      });
      if (!res.items.length)
        throw new Error("No collections found");
      return res;
    };
    const { data, status, error, hasNextPage, fetchNextPage, refetch } = useInfiniteQuery({
      queryKey: ["library:collections", textFilter, collection, isReversed, sortOption.id],
      queryFn: fetchRootlist,
      initialPageParam: 0,
      getNextPageParam: (lastPage) => {
        const current = lastPage.offset + limit5;
        if (lastPage.totalLength > current)
          return current;
      },
      retry: false,
      structuralSharing: false
    });
    (0, import_react26.useEffect)(() => {
      const update = (e) => {
        refetch();
      };
      CollectionsWrapper.addEventListener("update", update);
      return () => {
        CollectionsWrapper.removeEventListener("update", update);
      };
    }, [refetch]);
    const Status2 = useStatus_default(status, error);
    const props = {
      lhs: [
        collection ? /* @__PURE__ */ import_react26.default.createElement(back_button_default, {
          url: `Collections/${data?.pages[0].parentCollectionUri}`
        }) : null,
        data?.pages[0].openedCollectionName || "Collections"
      ],
      rhs: [
        /* @__PURE__ */ import_react26.default.createElement(add_button_default, {
          Menu: /* @__PURE__ */ import_react26.default.createElement(AddMenu5, {
            collection
          })
        }),
        sortDropdown,
        /* @__PURE__ */ import_react26.default.createElement(searchbar_default, {
          setSearch: setTextFilter,
          placeholder: "Collections"
        }),
        /* @__PURE__ */ import_react26.default.createElement(settings_button_default, {
          configWrapper
        })
      ]
    };
    if (Status2)
      return /* @__PURE__ */ import_react26.default.createElement(page_container_default, {
        ...props
      }, Status2);
    const contents = data;
    const items = contents.pages.flatMap((page) => page.items);
    const rootlistCards = items.map((item) => /* @__PURE__ */ import_react26.default.createElement(spotify_card_default, {
      provider: "spotify",
      type: item.type || "localalbum",
      uri: item.uri,
      header: item.name,
      subheader: item.type === "collection" ? `${item.items.length} Albums` : item.artists?.[0]?.name,
      imageUrl: item.type === "collection" ? item.image : item.images?.[0]?.url
    }));
    if (hasNextPage)
      rootlistCards.push(/* @__PURE__ */ import_react26.default.createElement(load_more_card_default, {
        callback: fetchNextPage
      }));
    return /* @__PURE__ */ import_react26.default.createElement(page_container_default, {
      ...props
    }, /* @__PURE__ */ import_react26.default.createElement("div", {
      className: "main-gridContainer-gridContainer grid"
    }, rootlistCards));
  };
  var collections_default = CollectionsPage;

  // ../shared/components/navigation/navigation_bar.tsx
  var import_react27 = __toESM(require_react());
  var import_react_dom = __toESM(require_react_dom());
  function NavigationBar({ links, selected, storekey }) {
    const { Chip } = Spicetify.ReactComponent;
    function navigate(page) {
      Spicetify.Platform.History.push(`/${storekey.split(":")[0]}/${page}`);
      Spicetify.LocalStorage.set(storekey, page);
    }
    return import_react_dom.default.createPortal(
      /* @__PURE__ */ import_react27.default.createElement("div", {
        style: { paddingTop: "8px", pointerEvents: "auto" }
      }, /* @__PURE__ */ import_react27.default.createElement("div", {
        className: "navbar-container"
      }, /* @__PURE__ */ import_react27.default.createElement("div", {
        className: "u_wTfCtgm9HvxrphUxKd"
      }, links.map(
        (link) => /* @__PURE__ */ import_react27.default.createElement(Chip, {
          "aria-label": link,
          selected: selected === link,
          selectedColorSet: "invertedLight",
          onClick: () => navigate(link)
        }, link)
      )))),
      document.querySelector(".main-topBar-topbarContentWrapper")
    );
  }
  var navigation_bar_default = NavigationBar;

  // src/app.tsx
  var checkForUpdates = (setNewUpdate) => {
    fetch("https://api.github.com/repos/harbassan/spicetify-apps/releases").then((res) => res.json()).then(
      (result) => {
        const releases = result.filter((release) => release.name.startsWith("library"));
        setNewUpdate(releases[0].name.slice(9) !== version);
      },
      (error) => {
        console.log("Failed to check for updates", error);
      }
    );
  };
  var NavbarContainer = ({ configWrapper }) => {
    const pages = {
      ["Artists"]: /* @__PURE__ */ import_react28.default.createElement(artists_default, {
        configWrapper
      }),
      ["Albums"]: /* @__PURE__ */ import_react28.default.createElement(albums_default, {
        configWrapper
      }),
      ["Shows"]: /* @__PURE__ */ import_react28.default.createElement(shows_default, {
        configWrapper
      }),
      ["Playlists"]: /* @__PURE__ */ import_react28.default.createElement(playlists_default, {
        configWrapper
      }),
      ["Collections"]: /* @__PURE__ */ import_react28.default.createElement(collections_default, {
        configWrapper
      })
    };
    const tabPages = ["Playlists", "Albums", "Collections", "Artists", "Shows"].filter(
      (page) => configWrapper.config[`show-${page.toLowerCase()}`]
    );
    const [newUpdate, setNewUpdate] = import_react28.default.useState(false);
    const activePage = Spicetify.Platform.History.location.pathname.split("/")[2];
    import_react28.default.useEffect(() => {
      checkForUpdates(setNewUpdate);
    }, []);
    import_react28.default.useEffect(() => {
      if (activePage === void 0) {
        const stored = Spicetify.LocalStorage.get("library:active-link") || "Albums";
        Spicetify.Platform.History.replace(`library/${stored}`);
      }
    }, [activePage]);
    if (activePage === void 0)
      return /* @__PURE__ */ import_react28.default.createElement(import_react28.default.Fragment, null);
    return /* @__PURE__ */ import_react28.default.createElement(import_react28.default.Fragment, null, /* @__PURE__ */ import_react28.default.createElement(navigation_bar_default, {
      links: tabPages,
      selected: activePage,
      storekey: "library:active-link"
    }), newUpdate && /* @__PURE__ */ import_react28.default.createElement("div", {
      className: "new-update"
    }, "New app update available! Visit", " ", /* @__PURE__ */ import_react28.default.createElement("a", {
      href: "https://github.com/harbassan/spicetify-apps/releases"
    }, "harbassan/spicetify-apps"), " to install."), pages[activePage]);
  };
  var waitForReady = async (callback) => {
    if (Spicetify.Platform && Spicetify.Platform.LibraryAPI && Spicetify.ReactQuery && SpicetifyLibrary) {
      callback();
    } else {
      setTimeout(() => waitForReady(callback), 1e3);
    }
  };
  var App = () => {
    const [config, setConfig] = import_react28.default.useState({});
    const [ready, setReady] = import_react28.default.useState(false);
    if (!ready) {
      waitForReady(() => {
        setConfig({ ...SpicetifyLibrary.ConfigWrapper.Config });
        setReady(true);
      });
      return /* @__PURE__ */ import_react28.default.createElement(import_react28.default.Fragment, null);
    }
    const launchModal = () => {
      SpicetifyLibrary.ConfigWrapper.launchModal(setConfig);
    };
    const configWrapper = {
      config,
      launchModal
    };
    return /* @__PURE__ */ import_react28.default.createElement("div", {
      id: "library-app"
    }, /* @__PURE__ */ import_react28.default.createElement(NavbarContainer, {
      configWrapper
    }));
  };
  var app_default = App;

  // ../../../AppData/Local/Temp/spicetify-creator/index.jsx
  var import_react29 = __toESM(require_react());
  function render() {
    return /* @__PURE__ */ import_react29.default.createElement(app_default, null);
  }
  return __toCommonJS(spicetify_creator_exports);
})();
const render=()=>library.default();
