using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class Account
{
    public int Id { get; set; }

    public string Code { get; set; } = null!;

    public string Name { get; set; } = null!;

    public int? ParentAccountId { get; set; }

    public string? PrintCode { get; set; }

    public virtual ICollection<Account> InverseParentAccount { get; set; } = new List<Account>();

    public virtual Account? ParentAccount { get; set; }
}
