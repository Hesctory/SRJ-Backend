using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class DebtStatus
{
    public short Id { get; set; }

    public string Code { get; set; } = null!;

    public string Name { get; set; } = null!;

    public bool IsTerminal { get; set; }

    public virtual ICollection<EnrollmentDebt> EnrollmentDebts { get; set; } = new List<EnrollmentDebt>();
}
