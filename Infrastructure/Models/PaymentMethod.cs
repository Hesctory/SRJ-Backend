using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class PaymentMethod
{
    public int Id { get; set; }

    public string Name { get; set; } = null!;
}
