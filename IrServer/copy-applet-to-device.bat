@rem This is used for even faster iteration -- see copy-to-device.sh for the first copy

@rem On device, as root must do:
@rem mkdir /usr/share/jive/applets/IrServer
pscp -scp IrServer*.lua root@192.168.0.74:/usr/share/jive/applets/IrServer/.

@rem You may also choose to:
@rem cd
@rem ln -s /usr/share/jive/applets/IrServer
@rem (creates symlink: IrServer -> /usr/share/jive/applets/IrServer )
