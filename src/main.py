from entrypoint import run

if __name__ == '__main__':
    try:
        print('MultiCloud FS started.')
        run()
    except KeyboardInterrupt:
        print('MultiCloud FS stopped.')