import os , sys ,time

from src.clean_data import main as clean_main
from src.load_to_mysql import main as load_main 
from src.validate import main as valid_main

def header(text):
    print("\n" + "=" * 60)
    print(text)
    print("=" * 60)

def run():
    start = time.time()
    try :
        header("step 1/3 : cleaning data ")
        clean_main()
        print("step 1 done ")

        header("step 2/3 : loading data to MySQL")
        load_main()
        print("step 2 done")

        header("step 3/3 : Validating the load")
        if not valid_main():
            print("\nPipeline FAILED at validation")
            sys.exit(1)
        print("Step 3 done")

    except SystemExit:
        raise  # the step already printed its own message
    except Exception as e:
        print(f"\nPipeline crashed: {type(e).__name__}: {e}")
        sys.exit(1)

    minutes = (time.time() - start) / 60
    header(f"Pipeline finished successfully in {minutes:.1f} minutes")


if __name__ == "__main__":
    run()