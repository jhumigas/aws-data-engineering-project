# Walkthrough 4: Data Generation (Lambda)

Simulate real-time application traffic.

- **IAM Role**: Create a role with access to RDS and Secrets Manager.
- **Function**: Deploy the Python script from `data_generator_lambda/`.
- **Packaging**: Use `uv` for packaging to ensure `mysql-connector-python` and `Faker` are included.
- **Secrets Manager**: Store DB credentials (host, port, user, password) as a JSON secret.

---

Next: [Walkthrough 5: Redshift Data Warehouse](./walkthrough-5-redshift.md)  
Back to [Walkthroughs](./README.md)
