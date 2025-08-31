# Zig Coffee Simulation: Project Overview

## Introduction
This document provides a comprehensive overview of the **Zig Coffee Simulation**, a project developed in the **Zig programming language**. The simulation is designed to model the intricate processes of coffee production, encompassing a range of activities from farming and harvesting to roasting, brewing, and commercial sales.

The project is architected as a collection of interconnected systems that collectively simulate the lifecycle and economy of coffee. Consequently, it serves as a robust foundation for developing more extensive applications, such as a coffee shop tycoon or a farming simulation game.

---

## Getting Started
To proceed with the compilation and execution of this project, an installation of the **Zig compiler** is a prerequisite.

### Building the Project
The application can be compiled by executing the `zig build` command from the root directory. As the project is currently a backend-only simulation, the main entry point (`main.zig`) is configured to print a confirmation message to the standard output upon a successful build.

```bash
zig build
````

### Running Automated Tests

The project is accompanied by a comprehensive suite of automated tests for each module, which serve to verify the correctness of the core logic. To execute all tests, please use the following command:

```bash
zig build test
```

-----

## System Features

The simulation is composed of several detailed systems, each with a specific functional domain:

  * **Farming System** (`farming.zig`): Facilitates the management of farms, including the configuration of customizable plots. It supports the planting of various seed types, each with unique growth curves, and simulates the progression of plant growth through distinct stages such as seed, seedling, flowering, and fruiting. The system culminates in the harvesting of crops, which yields a variable quantity of produce.
  * **Storage System** (`storage.zig`): Implements a generic inventory system for the management of in-game items. It supports the stacking of items according to defined capacity limits and provides functionality to store and retrieve specific quantities of items from designated storage slots.
  * **Roasting System** (`roasting.zig`): Defines and manages multiple coffee roast levels, which are categorized from light to dark (e.g., Cinnamon, City, French, Italian). This system is responsible for the creation of unique `RoastedCoffee` types based on the source beans and the applied roast level.
  * **Brewing System** (`brewing.zig`): Represents the terminal stage of the coffee production process. It defines `BrewedCoffee` entities, which possess final attributes such as strength and acidity.
  * **Flavor System** (`flavor.zig`): Implements a highly detailed and computationally efficient flavor profile system utilizing **bitflags**. Flavors are categorized into distinct notes, including floral, fruity, sweet, nutty, and minty. The system incorporates logic to combine and alter these flavors based on a set of predefined rules.
  * **Economy System** (`economy.zig`): Simulates a comprehensive economy featuring wallets, transactions, and a marketplace. The `WalletSystem` manages user balances through unique addresses, the `TransactionSystem` processes the creation and lifecycle of transactions, and the `MarketSystem` facilitates the buying and selling of products with dynamic pricing.
  * **Core Game Logic** (`game.zig`): Contains the foundational structure for a task system designed to handle asynchronous operations through the use of a thread pool.
  * **Utilities** (`bitwise.zig`): Provides a collection of helper functions for performing bitwise operations, which are utilized extensively by the `FlavorSystem` for the efficient management of flavor flags.

-----

## Architectural Overview

The project's source code is organized into the following distinct modules:

  * `main.zig`: Serves as the primary entry point for the application.
  * `game.zig`: Contains core game structures and task management logic.
  * `farming.zig`: Encapsulates all logic pertaining to the cultivation and harvesting of coffee plants.
  * `storage.zig`: Provides generic data structures for inventory management.
  * `roasting.zig`: Defines the coffee roasting process and associated profiles.
  * `brewing.zig`: Manages the final brewing stage of coffee production.
  * `flavor.zig`: Implements the system for managing complex flavor profiles.
  * `economy.zig`: Simulates the in-game economy, including financial accounts and a market.
  * `coffee.zig`: Contains core data structures pertinent to coffee.
  * `utils/bitwise.zig`: Offers helper functions for bitwise and bitflag manipulations.

The project's modular architecture establishes a clear **separation of concerns**, thereby enhancing both extensibility and maintainability.
