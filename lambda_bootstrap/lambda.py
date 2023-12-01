# Just a basic lambda bootstrap.


def run(event, context):
    """Print hello world."""
    print(event, context)


if __name__ == "__main__":
    run(None, None)
